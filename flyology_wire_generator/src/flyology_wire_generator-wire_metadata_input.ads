--  SPDX-License-Identifier: MIT OR Apache-2.0

private with Ada.Containers.Vectors;
private with Ada.Finalization;
private with Ada.Strings.Unbounded;
private with JSON.Parsers;
private with JSON.Types;
with Interfaces;

private package Flyology_Wire_Generator.Wire_Metadata_Input is
   type Decode_Limits is record
      Maximum_Source_Bytes       : Positive;
      Maximum_Depth              : Positive;
      Maximum_Nodes              : Positive;
      Maximum_Object_Members     : Positive;
      Maximum_Total_String_Bytes : Positive;
      Maximum_Number_Bytes       : Positive;
      Maximum_Work_Units         : Positive;
   end record;

   type Decode_Status is (Decoded, Rejected);

   type Error_Code is
     (No_Error,
      Source_Too_Large,
      Non_ASCII_Source,
      String_Escape_Rejected,
      Depth_Limit_Exceeded,
      Node_Limit_Exceeded,
      Object_Member_Limit_Exceeded,
      String_Limit_Exceeded,
      Number_Limit_Exceeded,
      Work_Limit_Exceeded,
      Invalid_Number,
      Duplicate_Key,
      Invalid_JSON,
      Unsupported_Metadata,
      Allocation_Failed,
      Internal_Error);

   type Error_Info is record
      Code       : Error_Code := No_Error;
      Has_Offset : Boolean := False;
      Offset     : Natural := 0;
   end record;

   function Message (Code : Error_Code) return String;

   type Value_Kind is (Object_Value, Array_Value, String_Value, Integer_Value, Boolean_Value, Null_Value);

   type Value_Cursor is private;
   No_Value : constant Value_Cursor;

   type Child_Cursor is private;
   No_Child : constant Child_Cursor;

   type Document is limited private;

   type Metadata_Format is
     (Schema_Lock_Format,
      Ada_Binding_Format,
      Compatibility_Approval_Format,
      Schema_Diff_Format,
      Type_IR_Overlay_Format,
      Type_IR_Consumer_Lock_Format,
      Type_IR_Provenance_Format);

   procedure Decode
     (Source          : String;
      Expected_Format : Metadata_Format;
      Limits          : Decode_Limits;
      Into            : in out Document;
      Status          : out Decode_Status;
      Error           : out Error_Info);

   function Is_Empty (Object : Document) return Boolean;
   function Root (Object : Document) return Value_Cursor;
   function Is_Valid (Object : Document; Value : Value_Cursor) return Boolean;
   function Is_Valid (Object : Document; Child : Child_Cursor) return Boolean;
   function Kind (Object : Document; Value : Value_Cursor) return Value_Kind;

   function Length (Object : Document; Value : Value_Cursor) return Natural;
   function Member (Object : Document; Value : Value_Cursor; Name : String) return Value_Cursor;
   function First_Child (Object : Document; Value : Value_Cursor) return Child_Cursor;
   function Next_Child (Object : Document; Child : Child_Cursor) return Child_Cursor;
   function Child_Name (Object : Document; Child : Child_Cursor) return String;
   function Child_Value (Object : Document; Child : Child_Cursor) return Value_Cursor;

   function Text (Object : Document; Value : Value_Cursor) return String;
   function As_Integer (Object : Document; Value : Value_Cursor) return Interfaces.Integer_64;
   function As_Boolean (Object : Document; Value : Value_Cursor) return Standard.Boolean;

private
   package Values is new
     JSON.Types
       (Integer_Type          => Interfaces.Integer_64,
        Float_Type            => Long_Long_Float,
        Maximum_Number_Length => Interfaces.Integer_64'Width);
   package Parsers is new
     JSON.Parsers (Types => Values, Default_Maximum_Depth => Positive'First, Check_Duplicate_Keys => False);

   package US renames Ada.Strings.Unbounded;

   type Snapshot_Identity is new Interfaces.Unsigned_64;
   No_Snapshot : constant Snapshot_Identity := 0;

   type Value_Index is new Natural;
   No_Value_Index : constant Value_Index := 0;

   type Value_Cursor is record
      Snapshot : Snapshot_Identity := No_Snapshot;
      Index    : Value_Index := No_Value_Index;
   end record;
   No_Value : constant Value_Cursor := (others => <>);

   type Edge_Cursor is new Natural;
   No_Edge : constant Edge_Cursor := 0;

   type Child_Cursor is record
      Snapshot : Snapshot_Identity := No_Snapshot;
      Edge     : Edge_Cursor := No_Edge;
   end record;
   No_Child : constant Child_Cursor := (others => <>);

   type Value_Record (Kind : Value_Kind := Null_Value) is record
      case Kind is
         when Object_Value | Array_Value =>
            First_Edge : Edge_Cursor := No_Edge;
            Last_Edge  : Edge_Cursor := No_Edge;
            Count      : Natural := 0;

         when String_Value =>
            String_Data : US.Unbounded_String;

         when Integer_Value =>
            Integer_Data : Interfaces.Integer_64 := 0;

         when Boolean_Value =>
            Boolean_Data : Standard.Boolean := False;

         when Null_Value =>
            null;
      end case;
   end record;

   type Edge_Record is record
      Name  : US.Unbounded_String;
      Value : Value_Index := No_Value_Index;
      Next  : Edge_Cursor := No_Edge;
   end record;

   package Value_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Value_Record);
   package Edge_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Edge_Record);

   type Arena is record
      Values : Value_Vectors.Vector;
      Edges  : Edge_Vectors.Vector;
   end record;
   type Arena_Access is access Arena;

   type Document is limited new Ada.Finalization.Limited_Controlled with record
      Data       : Arena_Access := null;
      Snapshot   : Snapshot_Identity := No_Snapshot;
      Root_Value : Value_Index := No_Value_Index;
   end record;

   overriding
   procedure Finalize (Object : in out Document);
end Flyology_Wire_Generator.Wire_Metadata_Input;
