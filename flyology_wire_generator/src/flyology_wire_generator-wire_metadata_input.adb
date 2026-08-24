--  SPDX-License-Identifier: MIT OR Apache-2.0

with Ada.Characters.Latin_1;
with Ada.Unchecked_Deallocation;
with Flyology_Wire_Generator.Test_Hooks;

package body Flyology_Wire_Generator.Wire_Metadata_Input is
   package L1 renames Ada.Characters.Latin_1;
   use type Interfaces.Integer_64;

   Audit_Failed : exception;

   type Parser_Access is access Parsers.Parser;

   procedure Free is new Ada.Unchecked_Deallocation (Object => Parsers.Parser, Name => Parser_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Object => Arena, Name => Arena_Access);

   protected Snapshot_Identities is
      procedure Take (Identity : out Snapshot_Identity);
   private
      Next : Snapshot_Identity := 1;
   end Snapshot_Identities;

   protected body Snapshot_Identities is
      procedure Take (Identity : out Snapshot_Identity) is
      begin
         Identity := Next;
         if Next = Snapshot_Identity'Last then
            Next := No_Snapshot;
         elsif Next /= No_Snapshot then
            Next := Next + 1;
         end if;
      end Take;
   end Snapshot_Identities;

   procedure Discard (Object : in out Parser_Access) is
   begin
      Free (Object);
   exception
      when others =>
         Object := null;
   end Discard;

   procedure Release (Object : in out Parser_Access; Released : out Boolean) is
   begin
      Free (Object);
      Released := True;
   exception
      when others =>
         Object := null;
         Released := False;
   end Release;

   procedure Discard (Object : in out Arena_Access) is
   begin
      Free (Object);
   exception
      when others =>
         Object := null;
   end Discard;

   procedure Reset (Object : in out Document) is
   begin
      Discard (Object.Data);
      Object.Snapshot := No_Snapshot;
      Object.Root_Value := No_Value_Index;
   end Reset;

   overriding
   procedure Finalize (Object : in out Document) is
   begin
      Reset (Object);
   end Finalize;

   function Is_Empty (Object : Document) return Boolean
   is (Object.Data = null);

   function Root (Object : Document) return Value_Cursor
   is ((if Object.Root_Value = No_Value_Index
        then No_Value
        else (Snapshot => Object.Snapshot, Index => Object.Root_Value)));

   function Is_Valid (Object : Document; Value : Value_Cursor) return Boolean
   is (Object.Data /= null
       and then Value.Snapshot /= No_Snapshot
       and then Value.Snapshot = Object.Snapshot
       and then Value.Index /= No_Value_Index
       and then Value.Index <= Value_Index (Object.Data.Values.Last_Index));

   function Value_At (Object : Document; Value : Value_Cursor) return Value_Record is
   begin
      if not Is_Valid (Object, Value) then
         raise Constraint_Error with "invalid JSON value cursor";
      end if;
      return Object.Data.Values.Element (Positive (Value.Index));
   end Value_At;

   function Is_Valid (Object : Document; Child : Child_Cursor) return Boolean
   is (Object.Data /= null
       and then Child.Snapshot /= No_Snapshot
       and then Child.Snapshot = Object.Snapshot
       and then Child.Edge /= No_Edge
       and then Child.Edge <= Edge_Cursor (Object.Data.Edges.Last_Index));

   function Edge_At (Object : Document; Child : Child_Cursor) return Edge_Record is
   begin
      if not Is_Valid (Object, Child) then
         raise Constraint_Error with "invalid JSON child cursor";
      end if;
      return Object.Data.Edges.Element (Positive (Child.Edge));
   end Edge_At;

   function Kind (Object : Document; Value : Value_Cursor) return Value_Kind
   is (Value_At (Object, Value).Kind);

   function Length (Object : Document; Value : Value_Cursor) return Natural is
      Item : constant Value_Record := Value_At (Object, Value);
   begin
      if Item.Kind not in Object_Value | Array_Value then
         raise Constraint_Error with "JSON value is not a container";
      end if;
      return Item.Count;
   end Length;

   function First_Child (Object : Document; Value : Value_Cursor) return Child_Cursor is
      Container : constant Value_Record := Value_At (Object, Value);
   begin
      if Container.Kind not in Object_Value | Array_Value then
         raise Constraint_Error with "JSON value is not a container";
      end if;
      if Container.First_Edge = No_Edge then
         return No_Child;
      end if;
      return (Snapshot => Object.Snapshot, Edge => Container.First_Edge);
   end First_Child;

   function Next_Child (Object : Document; Child : Child_Cursor) return Child_Cursor is
      Next : constant Edge_Cursor := Edge_At (Object, Child).Next;
   begin
      if Next = No_Edge then
         return No_Child;
      end if;
      return (Snapshot => Object.Snapshot, Edge => Next);
   end Next_Child;

   function Child_Name (Object : Document; Child : Child_Cursor) return String
   is (US.To_String (Edge_At (Object, Child).Name));

   function Child_Value (Object : Document; Child : Child_Cursor) return Value_Cursor
   is ((Snapshot => Object.Snapshot, Index => Edge_At (Object, Child).Value));

   function Member (Object : Document; Value : Value_Cursor; Name : String) return Value_Cursor is
      Container : constant Value_Record := Value_At (Object, Value);
      Cursor    : Edge_Cursor := Container.First_Edge;
   begin
      if Container.Kind /= Object_Value then
         raise Constraint_Error with "JSON value is not an object";
      end if;

      while Cursor /= No_Edge loop
         declare
            Edge : constant Edge_Record := Object.Data.Edges.Element (Positive (Cursor));
         begin
            if US.To_String (Edge.Name) = Name then
               return (Snapshot => Object.Snapshot, Index => Edge.Value);
            end if;
            Cursor := Edge.Next;
         end;
      end loop;
      return No_Value;
   end Member;

   function Text (Object : Document; Value : Value_Cursor) return String is
      Item : constant Value_Record := Value_At (Object, Value);
   begin
      if Item.Kind /= String_Value then
         raise Constraint_Error with "JSON value is not a string";
      end if;
      return US.To_String (Item.String_Data);
   end Text;

   function As_Integer (Object : Document; Value : Value_Cursor) return Interfaces.Integer_64 is
      Item : constant Value_Record := Value_At (Object, Value);
   begin
      if Item.Kind /= Integer_Value then
         raise Constraint_Error with "JSON value is not an integer";
      end if;
      return Item.Integer_Data;
   end As_Integer;

   function As_Boolean (Object : Document; Value : Value_Cursor) return Standard.Boolean is
      Item : constant Value_Record := Value_At (Object, Value);
   begin
      if Item.Kind /= Boolean_Value then
         raise Constraint_Error with "JSON value is not a Boolean";
      end if;
      return Item.Boolean_Data;
   end As_Boolean;

   function Message (Code : Error_Code) return String is
   begin
      case Code is
         when No_Error                     =>
            return "no error";

         when Source_Too_Large             =>
            return "JSON source exceeds its byte limit";

         when Non_ASCII_Source             =>
            return "wire metadata JSON must contain only ASCII bytes";

         when String_Escape_Rejected       =>
            return "wire metadata JSON does not permit string escapes";

         when Depth_Limit_Exceeded         =>
            return "JSON nesting exceeds its depth limit";

         when Node_Limit_Exceeded          =>
            return "JSON value count exceeds its node limit";

         when Object_Member_Limit_Exceeded =>
            return "JSON object exceeds its member limit";

         when String_Limit_Exceeded        =>
            return "JSON string bytes exceed their aggregate limit";

         when Number_Limit_Exceeded        =>
            return "JSON number token exceeds its byte limit";

         when Work_Limit_Exceeded          =>
            return "JSON validation exceeds its work-unit limit";

         when Invalid_Number               =>
            return "wire metadata requires canonical integer JSON numbers";

         when Duplicate_Key                =>
            return "JSON object contains a duplicate key";

         when Invalid_JSON                 =>
            return "invalid JSON";

         when Unsupported_Metadata         =>
            return "JSON is not the expected wire metadata format";

         when Allocation_Failed            =>
            return "allocation failed while decoding JSON";

         when Internal_Error               =>
            return "internal JSON decoder failure";
      end case;
   end Message;

   procedure Decode
     (Source          : String;
      Expected_Format : Metadata_Format;
      Limits          : Decode_Limits;
      Into            : in out Document;
      Status          : out Decode_Status;
      Error           : out Error_Info)
   is
      Working_Parser   : Parser_Access := null;
      Working_Data     : Arena_Access := null;
      Working_Root     : Value_Index := No_Value_Index;
      Working_Snapshot : Snapshot_Identity := No_Snapshot;
      Parser_Released  : Boolean;
      Failure          : Error_Info;
      Node_Count       : Natural := 0;
      String_Bytes     : Natural := 0;
      Work_Units       : Natural := 0;

      procedure Reject (Code : Error_Code; Offset : Natural) is
      begin
         Failure := (Code => Code, Has_Offset => True, Offset => Offset);
         raise Audit_Failed;
      end Reject;

      procedure Reject (Code : Error_Code) is
      begin
         Failure := (Code => Code, others => <>);
         raise Audit_Failed;
      end Reject;

      procedure Spend_Work is
      begin
         if Work_Units = Limits.Maximum_Work_Units then
            Reject (Work_Limit_Exceeded);
         end if;
         Work_Units := Work_Units + 1;
      end Spend_Work;

      procedure Preflight is
         type Container_Kind is (Object_Container, Array_Container);
         type Kind_Array is array (Positive range <>) of Container_Kind;
         type Count_Array is array (Positive range <>) of Natural;
         type Index_Array is array (Positive range <>) of Natural;

         type Key_Location is record
            First_Offset : Natural;
            Last_Offset  : Natural;
            Previous     : Natural;
         end record;
         package Key_Vectors is new
           Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Key_Location);

         Position     : Natural := 0;
         Depth        : Natural := 0;
         Source_Bytes : Natural := 0;
         Source_Nodes : Natural := 0;
         In_String    : Boolean := False;
         String_First : Natural := 0;
         Kinds        : Kind_Array (1 .. Limits.Maximum_Depth) := [others => Array_Container];
         Members      : Count_Array (1 .. Limits.Maximum_Depth) := [others => 0];
         Last_Key     : Index_Array (1 .. Limits.Maximum_Depth) := [others => 0];
         Keys         : Key_Vectors.Vector;

         function Character_At (Offset : Natural) return Character
         is (Source (Source'First + Offset));

         function Is_Delimiter (Value : Character) return Boolean
         is (Value in ' ' | L1.HT | L1.LF | L1.CR | ',' | ']' | '}');

         procedure Count_Node is
         begin
            if Source_Nodes = Limits.Maximum_Nodes then
               Reject (Node_Limit_Exceeded, Position);
            end if;
            Source_Nodes := Source_Nodes + 1;
         end Count_Node;

         function Same_Key (Left_First, Left_Last, Right_First, Right_Last : Natural) return Boolean is
            Length : constant Natural := Left_Last - Left_First;
         begin
            Spend_Work;
            if Length /= Right_Last - Right_First then
               return False;
            end if;
            if Length = 0 then
               return True;
            end if;
            for Offset in 0 .. Length - 1 loop
               Spend_Work;
               if Character_At (Left_First + Offset) /= Character_At (Right_First + Offset) then
                  return False;
               end if;
            end loop;
            return True;
         end Same_Key;

         procedure Register_Key (First_Offset, Last_Offset : Natural; At_Depth : Positive) is
            Cursor : Natural := Last_Key (At_Depth);
         begin
            while Cursor /= 0 loop
               declare
                  Existing : constant Key_Location := Keys.Element (Positive (Cursor));
               begin
                  if Same_Key (Existing.First_Offset, Existing.Last_Offset, First_Offset, Last_Offset) then
                     Reject (Duplicate_Key, First_Offset);
                  end if;
                  Cursor := Existing.Previous;
               end;
            end loop;
            Keys.Append
              (Key_Location'
                 (First_Offset => First_Offset, Last_Offset => Last_Offset, Previous => Last_Key (At_Depth)));
            Last_Key (At_Depth) := Natural (Keys.Last_Index);
         end Register_Key;
      begin
         if Source'Length > Limits.Maximum_Source_Bytes then
            Reject (Source_Too_Large, Limits.Maximum_Source_Bytes);
         end if;
         if Source'Length > Limits.Maximum_Work_Units then
            Reject (Work_Limit_Exceeded);
         end if;
         Work_Units := Source'Length;

         while Position < Source'Length loop
            declare
               Item : constant Character := Character_At (Position);
            begin
               if Character'Pos (Item) > 127 then
                  Reject (Non_ASCII_Source, Position);
               elsif Item = '\' then
                  if In_String then
                     Reject (String_Escape_Rejected, Position);
                  else
                     Reject (Invalid_JSON, Position);
                  end if;
               elsif Item = '"' then
                  if In_String then
                     declare
                        Lookahead : Natural := Position + 1;
                     begin
                        while Lookahead < Source'Length
                          and then Character_At (Lookahead) in ' ' | L1.HT | L1.LF | L1.CR
                        loop
                           Lookahead := Lookahead + 1;
                        end loop;
                        if Lookahead = Source'Length or else Character_At (Lookahead) /= ':' then
                           Count_Node;
                        elsif Depth > 0 and then Kinds (Depth) = Object_Container then
                           if Members (Depth) = Limits.Maximum_Object_Members then
                              Reject (Object_Member_Limit_Exceeded, Position);
                           end if;
                           Members (Depth) := Members (Depth) + 1;
                           Register_Key (String_First, Position, Depth);
                        end if;
                     end;
                  else
                     String_First := Position + 1;
                  end if;
                  In_String := not In_String;
               elsif In_String then
                  if Source_Bytes = Limits.Maximum_Total_String_Bytes then
                     Reject (String_Limit_Exceeded, Position);
                  end if;
                  Source_Bytes := Source_Bytes + 1;
               elsif Item in '{' | '[' then
                  if Depth = Limits.Maximum_Depth then
                     Reject (Depth_Limit_Exceeded, Position);
                  end if;
                  Count_Node;
                  Depth := Depth + 1;
                  Kinds (Depth) := (if Item = '{' then Object_Container else Array_Container);
                  Members (Depth) := 0;
                  Last_Key (Depth) := 0;
               elsif Item in '}' | ']' then
                  if Depth > 0 then
                     Depth := Depth - 1;
                  end if;
               elsif Item = '-' or else Item in '0' .. '9' then
                  declare
                     Start    : constant Natural := Position;
                     Negative : constant Boolean := Item = '-';
                  begin
                     if Negative then
                        Position := Position + 1;
                        if Position = Source'Length or else Character_At (Position) not in '0' .. '9' then
                           Reject (Invalid_Number, Start);
                        end if;
                     end if;

                     if Character_At (Position) = '0' then
                        if Negative then
                           Reject (Invalid_Number, Start);
                        end if;
                        Position := Position + 1;
                        if Position < Source'Length and then Character_At (Position) in '0' .. '9' then
                           Reject (Invalid_Number, Start);
                        end if;
                     else
                        while Position < Source'Length and then Character_At (Position) in '0' .. '9' loop
                           Position := Position + 1;
                        end loop;
                     end if;

                     if Position < Source'Length and then not Is_Delimiter (Character_At (Position)) then
                        Reject (Invalid_Number, Start);
                     elsif Position - Start > Limits.Maximum_Number_Bytes then
                        Reject (Number_Limit_Exceeded, Start);
                     end if;
                     declare
                        Number       : constant String :=
                          Source (Source'First + Start .. Source'First + (Position - 1));
                        Digits_First : constant Positive :=
                          (if Negative then Number'First + 1 else Number'First);
                        Magnitude    : constant String := Number (Digits_First .. Number'Last);
                        Bound        : constant String :=
                          (if Negative then "9223372036854775808" else "9223372036854775807");
                     begin
                        if Magnitude'Length > Bound'Length
                          or else (Magnitude'Length = Bound'Length and then Magnitude > Bound)
                        then
                           Reject (Invalid_Number, Start);
                        end if;
                     end;
                     Count_Node;
                     Position := Position - 1;
                  end;
               elsif Item in 't' | 'f' | 'n' then
                  Count_Node;
               end if;
            end;
            Position := Position + 1;
         end loop;
      end Preflight;

      procedure Count_String (Item : String) is
      begin
         if Item'Length > Limits.Maximum_Total_String_Bytes
           or else String_Bytes > Limits.Maximum_Total_String_Bytes - Item'Length
         then
            Reject (String_Limit_Exceeded);
         end if;
         String_Bytes := String_Bytes + Item'Length;
      end Count_String;

      function Add_Value (Item : Value_Record) return Value_Index is
      begin
         if Node_Count = Limits.Maximum_Nodes then
            Reject (Node_Limit_Exceeded);
         end if;
         Node_Count := Node_Count + 1;
         Working_Data.Values.Append (Item);
         return Value_Index (Working_Data.Values.Last_Index);
      end Add_Value;

      procedure Add_Edge (Container : Value_Index; Name : String; Child : Value_Index) is
         Parent       : Value_Record := Working_Data.Values.Element (Positive (Container));
         Current_Edge : Edge_Cursor;
      begin
         Working_Data.Edges.Append
           (Edge_Record'(Name => US.To_Unbounded_String (Name), Value => Child, Next => No_Edge));
         Current_Edge := Edge_Cursor (Working_Data.Edges.Last_Index);

         if Parent.Last_Edge = No_Edge then
            Parent.First_Edge := Current_Edge;
         else
            declare
               Previous : Edge_Record := Working_Data.Edges.Element (Positive (Parent.Last_Edge));
            begin
               Previous.Next := Current_Edge;
               Working_Data.Edges.Replace_Element (Positive (Parent.Last_Edge), Previous);
            end;
         end if;

         Parent.Last_Edge := Current_Edge;
         Parent.Count := Parent.Count + 1;
         Working_Data.Values.Replace_Element (Positive (Container), Parent);
      end Add_Edge;

      function Convert (Item : Values.JSON_Value) return Value_Index is
         Result : Value_Index;
      begin
         case Item.Kind is
            when Values.Object_Kind  =>
               Result := Add_Value (Value_Record'(Kind => Object_Value, others => <>));
               for Key of Item loop
                  declare
                     Name  : constant String := Key.Value;
                     Child : Value_Index;
                  begin
                     Count_String (Name);
                     --  JSON.Types.Get performs a linear key lookup. Charge a
                     --  conservative candidate and comparison-byte upper bound.
                     declare
                        Candidate : Natural := 0;
                     begin
                        while Candidate < Item.Length loop
                           Spend_Work;
                           Candidate := Candidate + 1;
                           declare
                              Compared_Bytes : Natural := 0;
                           begin
                              while Compared_Bytes < Name'Length loop
                                 Spend_Work;
                                 Compared_Bytes := Compared_Bytes + 1;
                              end loop;
                           end;
                        end loop;
                     end;
                     Child := Convert (Item.Get (Name));
                     Add_Edge (Result, Name, Child);
                  end;
               end loop;
               return Result;

            when Values.Array_Kind   =>
               Result := Add_Value (Value_Record'(Kind => Array_Value, others => <>));
               for Child of Item loop
                  Add_Edge (Result, "", Convert (Child));
               end loop;
               return Result;

            when Values.String_Kind  =>
               declare
                  Content : constant String := Item.Value;
               begin
                  Count_String (Content);
                  return
                    Add_Value
                      (Value_Record'(Kind => String_Value, String_Data => US.To_Unbounded_String (Content)));
               end;

            when Values.Integer_Kind =>
               return Add_Value (Value_Record'(Kind => Integer_Value, Integer_Data => Item.Value));

            when Values.Boolean_Kind =>
               return Add_Value (Value_Record'(Kind => Boolean_Value, Boolean_Data => Item.Value));

            when Values.Null_Kind    =>
               return Add_Value (Value_Record'(Kind => Null_Value));

            when Values.Float_Kind   =>
               Reject (Invalid_Number);
               return No_Value_Index;
         end case;
      end Convert;

      function Find_Member (Container : Value_Index; Name : String) return Value_Index is
         Parent : constant Value_Record := Working_Data.Values.Element (Positive (Container));
      begin
         if Parent.Kind /= Object_Value then
            return No_Value_Index;
         end if;
         declare
            Cursor : Edge_Cursor := Parent.First_Edge;
         begin
            while Cursor /= No_Edge loop
               declare
                  Edge : constant Edge_Record := Working_Data.Edges.Element (Positive (Cursor));
               begin
                  if US.To_String (Edge.Name) = Name then
                     return Edge.Value;
                  end if;
                  Cursor := Edge.Next;
               end;
            end loop;
         end;
         return No_Value_Index;
      end Find_Member;

      function Format_Key return String
      is (case Expected_Format is
            when Schema_Lock_Format            => "lock_format",
            when Ada_Binding_Format            => "binding_format",
            when Compatibility_Approval_Format => "approval_format",
            when Schema_Diff_Format            => "diff_format",
            when Type_IR_Overlay_Format        => "overlay_format",
            when Type_IR_Consumer_Lock_Format  => "consumer_format",
            when Type_IR_Provenance_Format     => "consumer_format");

      function Version_Key return String
      is (case Expected_Format is
            when Schema_Lock_Format            => "lock_version",
            when Ada_Binding_Format            => "binding_version",
            when Compatibility_Approval_Format => "approval_version",
            when Schema_Diff_Format            => "diff_version",
            when Type_IR_Overlay_Format        => "overlay_version",
            when Type_IR_Consumer_Lock_Format  => "consumer_version",
            when Type_IR_Provenance_Format     => "consumer_version");

      function Format_Value return String
      is (case Expected_Format is
            when Schema_Lock_Format            => "flyology-wire-schema-lock",
            when Ada_Binding_Format            => "flyology-wire-ada-binding",
            when Compatibility_Approval_Format => "flyology-wire-compatibility-approval",
            when Schema_Diff_Format            => "flyology-wire-schema-diff",
            when Type_IR_Overlay_Format        => "flyology-wire-type-ir-overlay",
            when Type_IR_Consumer_Lock_Format  => "flyology-wire-type-ir-consumer-lock",
            when Type_IR_Provenance_Format     => "flyology-wire-type-ir-provenance");

      procedure Validate_Metadata is
         Format_Node  : constant Value_Index := Find_Member (Working_Root, Format_Key);
         Version_Node : constant Value_Index := Find_Member (Working_Root, Version_Key);
      begin
         if Format_Node = No_Value_Index
           or else Version_Node = No_Value_Index
           or else Working_Data.Values.Element (Positive (Format_Node)).Kind /= String_Value
           or else US.To_String (Working_Data.Values.Element (Positive (Format_Node)).String_Data)
                   /= Format_Value
           or else Working_Data.Values.Element (Positive (Version_Node)).Kind /= Integer_Value
           or else Working_Data.Values.Element (Positive (Version_Node)).Integer_Data /= 1
         then
            Reject (Unsupported_Metadata);
         end if;
      end Validate_Metadata;

      function Parser_Depth return Positive
      is (if Limits.Maximum_Depth = Positive'Last then Positive'Last else Limits.Maximum_Depth + 1);

      function Parse_Source return Values.JSON_Value is
      begin
         Working_Parser :=
           new Parsers.Parser'(Parsers.Create (Text => Source, Maximum_Depth => Parser_Depth));
         return Working_Parser.Parse;
      exception
         when Parsers.Parse_Error =>
            Reject (Invalid_JSON);
            return Values.Create_Null;
      end Parse_Source;
   begin
      Status := Rejected;
      Error := (others => <>);

      Preflight;
      Snapshot_Identities.Take (Working_Snapshot);
      if Working_Snapshot = No_Snapshot then
         Reject (Internal_Error);
      end if;
      Working_Data := new Arena;
      declare
         Parsed_Root : constant Values.JSON_Value := Parse_Source;
      begin
         Working_Root := Convert (Parsed_Root);
      end;
      Release (Working_Parser, Parser_Released);
      if Flyology_Wire_Generator.Test_Hooks.Enabled then
         if Flyology_Wire_Generator.Test_Hooks.Consume_Parser_Release_Failure then
            Parser_Released := False;
         end if;
      end if;
      if not Parser_Released then
         Reject (Internal_Error);
      end if;
      Validate_Metadata;

      declare
         Old_Data : Arena_Access := Into.Data;
      begin
         Into.Data := Working_Data;
         Into.Snapshot := Working_Snapshot;
         Into.Root_Value := Working_Root;
         Working_Data := null;
         Status := Decoded;
         Discard (Old_Data);
      end;
   exception
      when Audit_Failed =>
         Error := Failure;
         Discard (Working_Parser);
         Discard (Working_Data);
      when Constraint_Error | Parsers.Parse_Error =>
         Error := (Code => Internal_Error, others => <>);
         Discard (Working_Parser);
         Discard (Working_Data);
      when Storage_Error =>
         Error := (Code => Allocation_Failed, others => <>);
         Discard (Working_Parser);
         Discard (Working_Data);
      when others =>
         Error := (Code => Internal_Error, others => <>);
         Discard (Working_Parser);
         Discard (Working_Data);
   end Decode;
end Flyology_Wire_Generator.Wire_Metadata_Input;
