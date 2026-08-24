--  SPDX-License-Identifier: MIT OR Apache-2.0

with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Flyology_Wire_Generator.Test_Hooks;
with Flyology_Wire_Generator.Wire_Metadata_Input;
with Interfaces;

procedure Flyology_Wire_Generator.Wire_Metadata_Input_Tests is
   package Input renames Flyology_Wire_Generator.Wire_Metadata_Input;
   use type Input.Decode_Status;
   use type Input.Error_Code;
   use type Input.Metadata_Format;
   use type Input.Value_Cursor;
   use type Input.Value_Kind;
   use type Interfaces.Integer_64;

   --  These are fixture-local capacities, not generator format policy.
   Test_Limits : constant Input.Decode_Limits :=
     (Maximum_Source_Bytes       => 1_048_576,
      Maximum_Depth              => 64,
      Maximum_Nodes              => 100_000,
      Maximum_Object_Members     => 64,
      Maximum_Total_String_Bytes => 1_048_576,
      Maximum_Number_Bytes       => 64,
      Maximum_Work_Units         => 1_048_576);
   package US renames Ada.Strings.Unbounded;

   Lock_Prefix : constant String := "{""lock_format"":""flyology-wire-schema-lock"",""lock_version"":1";

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Check;

   procedure Decode
     (Source          : String;
      Expected_Format : Input.Metadata_Format;
      Limits          : Input.Decode_Limits;
      Into            : in out Input.Document;
      Status          : out Input.Decode_Status;
      Error           : out Input.Error_Info) is
   begin
      Input.Decode (Source, Expected_Format, Limits, Into, Status, Error);
   end Decode;

   procedure Expect_Rejected
     (Source          : String;
      Expected        : Input.Error_Code;
      Limits          : Input.Decode_Limits := Test_Limits;
      Expected_Format : Input.Metadata_Format := Input.Schema_Lock_Format)
   is
      Document : Input.Document;
      Status   : Input.Decode_Status;
      Error    : Input.Error_Info;
   begin
      Decode (Source, Expected_Format, Limits, Document, Status, Error);
      Check (Status = Input.Rejected, "invalid JSON was accepted");
      Check (Error.Code = Expected, "wrong rejection for " & Source & ": " & Input.Message (Error.Code));
      Check (Input.Is_Empty (Document), "rejected JSON published a document");
   end Expect_Rejected;

   procedure Valid_Document is
      Source      : constant String :=
        Lock_Prefix
        & ",""minimum"":-9223372036854775808,""maximum"":9223372036854775807"
        & ",""items"":[null,""text""],""enabled"":true}";
      Replacement : constant String := Lock_Prefix & ",""replacement"":2}";
      First       : Input.Document;
      Second      : Input.Document;
      Identical   : Input.Document;
      Status      : Input.Decode_Status;
      Error       : Input.Error_Info;
      Root        : Input.Value_Cursor;
      Items       : Input.Value_Cursor;
      Old         : Input.Value_Cursor;
      Child       : Input.Child_Cursor;
      Old_Child   : Input.Child_Cursor;
   begin
      Decode (Source, Input.Schema_Lock_Format, Test_Limits, First, Status, Error);
      Check (Status = Input.Decoded, Input.Message (Error.Code));
      Check (Error.Code = Input.No_Error, "successful decode retained an error");
      Root := Input.Root (First);
      Check (Input.Kind (First, Root) = Input.Object_Value, "root is not an object");
      Check (Input.Length (First, Root) = 6, "wrong object length");
      Child := Input.First_Child (First, Root);
      Check (Input.Child_Name (First, Child) = "lock_format", "wrong first member name");
      Check
        (Input.Text (First, Input.Child_Value (First, Child)) = "flyology-wire-schema-lock",
         "wrong first member value");
      Check
        (Input.As_Integer (First, Input.Member (First, Root, "minimum")) = Interfaces.Integer_64'First,
         "wrong minimum integer");
      Check
        (Input.As_Integer (First, Input.Member (First, Root, "maximum")) = Interfaces.Integer_64'Last,
         "wrong maximum integer");
      Check (Input.As_Boolean (First, Input.Member (First, Root, "enabled")), "wrong Boolean value");
      Items := Input.Member (First, Root, "items");
      Check (Input.Kind (First, Items) = Input.Array_Value, "wrong array value");
      Child := Input.First_Child (First, Items);
      Check (Input.Kind (First, Input.Child_Value (First, Child)) = Input.Null_Value, "wrong null item");
      Child := Input.Next_Child (First, Child);
      Check (Input.Text (First, Input.Child_Value (First, Child)) = "text", "wrong text item");
      Check (not Input.Is_Valid (First, Input.Next_Child (First, Child)), "array traversal did not end");
      Old_Child := Child;
      Check (Input.Member (First, Root, "missing") = Input.No_Value, "missing member was found");

      Decode (Source, Input.Schema_Lock_Format, Test_Limits, Identical, Status, Error);
      Check (Status = Input.Decoded, "identical second document was rejected");
      Check (not Input.Is_Valid (Identical, Root), "same-bytes cross-document value cursor was accepted");
      Check
        (not Input.Is_Valid (First, Input.Root (Identical)),
         "same-bytes reverse cross-document value cursor was accepted");
      Check
        (not Input.Is_Valid (Identical, Old_Child), "same-bytes cross-document child cursor was accepted");

      Decode (Replacement, Input.Schema_Lock_Format, Test_Limits, Second, Status, Error);
      Check (Status = Input.Decoded, "second document was rejected");
      Check (not Input.Is_Valid (Second, Root), "cross-document cursor was accepted");
      Check (not Input.Is_Valid (First, Input.Root (Second)), "reverse cross-document cursor was accepted");
      Check (not Input.Is_Valid (Second, Old_Child), "cross-document child cursor was accepted");

      Old := Root;
      Decode ("{", Input.Schema_Lock_Format, Test_Limits, First, Status, Error);
      Check (Status = Input.Rejected, "malformed replacement was accepted");
      Check (Input.Is_Valid (First, Old), "failed replacement invalidated the old snapshot");
      Check (Input.Is_Valid (First, Old_Child), "failed replacement invalidated the old child cursor");
      Check (Input.Length (First, Old) = 6, "failed replacement changed the old snapshot");

      Decode ("{""ir_version"":1}", Input.Schema_Lock_Format, Test_Limits, First, Status, Error);
      Check (Status = Input.Rejected, "wrong-format replacement was accepted");
      Check (Input.Is_Valid (First, Old), "semantic rejection invalidated the old snapshot");

      Decode (Replacement, Input.Schema_Lock_Format, Test_Limits, First, Status, Error);
      Check (Status = Input.Decoded, "valid replacement was rejected");
      Check (not Input.Is_Valid (First, Old), "successful replacement retained a stale cursor");
      Check (not Input.Is_Valid (First, Old_Child), "successful replacement retained a stale child cursor");
      Check (Input.Is_Valid (First, Input.Root (First)), "replacement root is invalid");
   end Valid_Document;

   procedure Exact_Limits is
      Minimal      : constant String := Lock_Prefix & "}";
      Nested       : constant String := Lock_Prefix & ",""nested"":{}}";
      Number       : constant String := Lock_Prefix & ",""number"":10}";
      Format_Key   : constant String := "lock_format";
      Format_Value : constant String := "flyology-wire-schema-lock";
      Version_Key  : constant String := "lock_version";
      Strings      : constant Positive := Format_Key'Length + Format_Value'Length + Version_Key'Length;
      Minimal_Work : constant Positive :=
        Minimal'Length + 1 + 2 * (1 + Format_Key'Length) + 2 * (1 + Version_Key'Length);
      Whitespace   : constant String (1 .. 128) := [others => ' '];
      Limits       : Input.Decode_Limits := Test_Limits;
      Document     : Input.Document;
      Status       : Input.Decode_Status;
      Error        : Input.Error_Info;

      procedure Expect_Decoded (Source : String; Applied : Input.Decode_Limits) is
      begin
         Decode (Source, Input.Schema_Lock_Format, Applied, Document, Status, Error);
         Check (Status = Input.Decoded, "exact limit rejected: " & Input.Message (Error.Code));
      end Expect_Decoded;
   begin
      Limits.Maximum_Source_Bytes := Minimal'Length;
      Expect_Decoded (Minimal, Limits);
      Limits.Maximum_Source_Bytes := Minimal'Length - 1;
      Expect_Rejected (Minimal, Input.Source_Too_Large, Limits);

      Limits := Test_Limits;
      Limits.Maximum_Depth := 2;
      Expect_Decoded (Nested, Limits);
      Limits.Maximum_Depth := 1;
      Expect_Rejected (Nested, Input.Depth_Limit_Exceeded, Limits);

      Limits := Test_Limits;
      Limits.Maximum_Nodes := 3;
      Expect_Decoded (Minimal, Limits);
      Limits.Maximum_Nodes := 2;
      Expect_Rejected (Minimal, Input.Node_Limit_Exceeded, Limits);

      Limits := Test_Limits;
      Limits.Maximum_Object_Members := 2;
      Expect_Decoded (Minimal, Limits);
      Limits.Maximum_Object_Members := 1;
      Expect_Rejected (Minimal, Input.Object_Member_Limit_Exceeded, Limits);

      Limits := Test_Limits;
      Limits.Maximum_Total_String_Bytes := Strings;
      Expect_Decoded (Minimal, Limits);
      Limits.Maximum_Total_String_Bytes := Strings - 1;
      Expect_Rejected (Minimal, Input.String_Limit_Exceeded, Limits);

      Limits := Test_Limits;
      Limits.Maximum_Number_Bytes := 1;
      Expect_Decoded (Minimal, Limits);
      Expect_Rejected (Number, Input.Number_Limit_Exceeded, Limits);

      Limits := Test_Limits;
      Limits.Maximum_Work_Units := Minimal_Work;
      Expect_Decoded (Minimal, Limits);
      Limits.Maximum_Work_Units := Minimal_Work - 1;
      Expect_Rejected (Minimal, Input.Work_Limit_Exceeded, Limits);

      Limits := Test_Limits;
      Limits.Maximum_Work_Units := 5;
      Expect_Rejected ("12345", Input.Unsupported_Metadata, Limits);
      Limits.Maximum_Work_Units := 4;
      Expect_Rejected ("12345", Input.Work_Limit_Exceeded, Limits);

      Limits := Test_Limits;
      Limits.Maximum_Work_Units := 3;
      Expect_Rejected ("""x""" & Whitespace, Input.Work_Limit_Exceeded, Limits);
   end Exact_Limits;

   procedure Parser_Release_Failure is
      Source      : constant String := Lock_Prefix & "}";
      Replacement : constant String := Lock_Prefix & ",""replacement"":2}";
      Document    : Input.Document;
      Status      : Input.Decode_Status;
      Error       : Input.Error_Info;
      Root        : Input.Value_Cursor;
      Child       : Input.Child_Cursor;
   begin
      Input.Decode (Source, Input.Schema_Lock_Format, Test_Limits, Document, Status, Error);
      Check (Status = Input.Decoded, "initial release-failure fixture was rejected");
      Root := Input.Root (Document);
      Child := Input.First_Child (Document, Root);

      Check (Flyology_Wire_Generator.Test_Hooks.Enabled, "parser-release test hooks are disabled");
      Flyology_Wire_Generator.Test_Hooks.Arm_Parser_Release_Failure;
      Input.Decode (Replacement, Input.Schema_Lock_Format, Test_Limits, Document, Status, Error);
      Check (Status = Input.Rejected, "simulated parser-release failure was accepted");
      Check (Error.Code = Input.Internal_Error, "parser-release failure had the wrong status");
      Check (Input.Is_Valid (Document, Root), "parser-release failure replaced the prior document");
      Check (Input.Is_Valid (Document, Child), "parser-release failure invalidated a child cursor");
      Check (Input.Length (Document, Root) = 2, "parser-release failure changed the prior document");
   end Parser_Release_Failure;

   procedure Discriminator_Rejections is
      Minimal : constant String := Lock_Prefix & "}";
   begin
      Expect_Rejected ("{""lock_version"":1}", Input.Unsupported_Metadata);
      Expect_Rejected ("{""lock_format"":""flyology-wire-schema-lock""}", Input.Unsupported_Metadata);
      Expect_Rejected ("{""lock_format"":""wrong"",""lock_version"":1}", Input.Unsupported_Metadata);
      Expect_Rejected ("{""lock_format"":1,""lock_version"":1}", Input.Unsupported_Metadata);
      Expect_Rejected
        ("{""lock_format"":""flyology-wire-schema-lock"",""lock_version"":""1""}",
         Input.Unsupported_Metadata);
      Expect_Rejected
        ("{""lock_format"":""flyology-wire-schema-lock"",""lock_version"":2}", Input.Unsupported_Metadata);

      for Expected_Format in Input.Metadata_Format loop
         if Expected_Format /= Input.Schema_Lock_Format then
            Expect_Rejected (Minimal, Input.Unsupported_Metadata, Expected_Format => Expected_Format);
         end if;
      end loop;
   end Discriminator_Rejections;

   procedure Arbitrary_Lower_Bound is
      Plain    : constant String := Lock_Prefix & "}";
      Source   : constant String (Positive'Last - Plain'Length + 1 .. Positive'Last) := Plain;
      Document : Input.Document;
      Status   : Input.Decode_Status;
      Error    : Input.Error_Info;
   begin
      Decode (Source, Input.Schema_Lock_Format, Test_Limits, Document, Status, Error);
      Check (Status = Input.Decoded, "extreme lower-bound source was rejected");
   end Arbitrary_Lower_Bound;

   function Read_File (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Result : US.Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         US.Append (Result, Ada.Text_IO.Get_Line (File));
         US.Append (Result, Ada.Characters.Latin_1.LF);
      end loop;
      Ada.Text_IO.Close (File);
      return US.To_String (Result);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Read_File;

   function Ends_With (Value, Suffix : String) return Boolean
   is (Value'Length >= Suffix'Length and then Value (Value'Last - Suffix'Length + 1 .. Value'Last) = Suffix);

   function Format_For (Path : String) return Input.Metadata_Format is
   begin
      if Ends_With (Path, ".ada-binding.json") then
         return Input.Ada_Binding_Format;
      elsif Ends_With (Path, ".approval.json") then
         return Input.Compatibility_Approval_Format;
      elsif Ends_With (Path, ".diff.json") then
         return Input.Schema_Diff_Format;
      elsif Ends_With (Path, ".overlay.json") then
         return Input.Type_IR_Overlay_Format;
      elsif Ends_With (Path, ".provenance.json") then
         return Input.Type_IR_Provenance_Format;
      else
         return Input.Schema_Lock_Format;
      end if;
   end Format_For;

   procedure Check_File (Path : String; Expected_Format : Input.Metadata_Format) is
      Document : Input.Document;
      Status   : Input.Decode_Status;
      Error    : Input.Error_Info;
   begin
      Decode (Read_File (Path), Expected_Format, Test_Limits, Document, Status, Error);
      Check (Status = Input.Decoded, Path & ": " & Input.Message (Error.Code));
   end Check_File;

   procedure Check_Directory (Path : String) is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      Filter : constant Ada.Directories.Filter_Type :=
        [Ada.Directories.Ordinary_File => True, others => False];
   begin
      Ada.Directories.Start_Search (Search, Path, "*.json", Filter);
      begin
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               File_Path : constant String := Ada.Directories.Full_Name (Item);
            begin
               Check_File (File_Path, Format_For (File_Path));
            end;
         end loop;
      exception
         when others =>
            Ada.Directories.End_Search (Search);
            raise;
      end;
      Ada.Directories.End_Search (Search);
   end Check_Directory;

   Small_Source : Input.Decode_Limits := Test_Limits;
   Small_Depth  : Input.Decode_Limits := Test_Limits;
   Small_Nodes  : Input.Decode_Limits := Test_Limits;
   Small_Object : Input.Decode_Limits := Test_Limits;
   Small_String : Input.Decode_Limits := Test_Limits;
   Small_Number : Input.Decode_Limits := Test_Limits;
begin
   Valid_Document;
   Exact_Limits;
   Discriminator_Rejections;
   Arbitrary_Lower_Bound;
   Parser_Release_Failure;

   Expect_Rejected ("{""a"":1,""a"":2}", Input.Duplicate_Key);
   declare
      Large_Key : constant String (1 .. 4_096) := [others => 'x'];
   begin
      Expect_Rejected ("{""" & Large_Key & """:1,""" & Large_Key & """:2}", Input.Duplicate_Key);
   end;
   Expect_Rejected ("{""x"":""a\/b""}", Input.String_Escape_Rejected);
   Expect_Rejected ("\", Input.Invalid_JSON);
   Expect_Rejected ("{""x"":""" & Character'Val (16#80#) & """}", Input.Non_ASCII_Source);
   Expect_Rejected ("1.0", Input.Invalid_Number);
   Expect_Rejected ("1e2", Input.Invalid_Number);
   Expect_Rejected ("01", Input.Invalid_Number);
   Expect_Rejected ("-0", Input.Invalid_Number);
   Expect_Rejected ("-", Input.Invalid_Number);
   Expect_Rejected ("9223372036854775808", Input.Invalid_Number);
   Expect_Rejected ("-9223372036854775809", Input.Invalid_Number);
   Expect_Rejected ("[1,", Input.Invalid_JSON);
   Expect_Rejected ("{""a"":1,}", Input.Invalid_JSON);
   Expect_Rejected ("{""ir_version"":1,""required_features"":[]}", Input.Unsupported_Metadata);

   Small_Source.Maximum_Source_Bytes := 2;
   Expect_Rejected ("null", Input.Source_Too_Large, Small_Source);

   Small_Depth.Maximum_Depth := 1;
   Expect_Rejected ("[[]]", Input.Depth_Limit_Exceeded, Small_Depth);

   Small_Nodes.Maximum_Nodes := 2;
   Expect_Rejected ("[1,2]", Input.Node_Limit_Exceeded, Small_Nodes);

   Small_Object.Maximum_Object_Members := 1;
   Expect_Rejected ("{""a"":1,""b"":2}", Input.Object_Member_Limit_Exceeded, Small_Object);

   Small_String.Maximum_Total_String_Bytes := 3;
   Expect_Rejected ("{""aa"":""bb""}", Input.String_Limit_Exceeded, Small_String);

   Small_Number.Maximum_Number_Bytes := 3;
   Expect_Rejected ("1234", Input.Number_Limit_Exceeded, Small_Number);

   Check (Ada.Command_Line.Argument_Count = 1, "schema directory argument missing");
   Check_Directory (Ada.Directories.Compose (Ada.Command_Line.Argument (1), "fixtures"));
   Check_File
     (Ada.Directories.Compose (Ada.Command_Line.Argument (1), "type-ir-consumer.lock.json"),
      Input.Type_IR_Consumer_Lock_Format);

   Ada.Text_IO.Put_Line ("wire metadata input tests passed");
end Flyology_Wire_Generator.Wire_Metadata_Input_Tests;
