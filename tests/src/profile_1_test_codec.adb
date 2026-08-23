with Flyology_Wire.Compatibility;
with Flyology_Wire.Profiles.Tagged_Profile;
with Flyology_Wire.Sizes;

package body Profile_1_Test_Codec is
   package Compatibility renames Flyology_Wire.Compatibility;
   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;
   package Sizes renames Flyology_Wire.Sizes;

   use type Compatibility.Schema_Relationship;
   use type Flyology_Wire.Codecs.Measure_Status;
   use type Flyology_Wire.Codecs.Schema_Identity;
   use type Flyology_Wire.Octet_Count;
   use type Interfaces.Unsigned_64;
   use type Profile.Cursor_Status;
   use type Profile.Field_Tag;
   use type Profile.Read_Status;
   use type Profile.Write_Status;
   use type Sizes.Arithmetic_Status;

   Accepted_Writers : constant Compatibility.Schema_Identity_Array := [1 => Older_Schema, 2 => Future_Schema];

   Code_Tag    : constant Profile.Field_Tag := 1;
   Enabled_Tag : constant Profile.Field_Tag := 2;
   Future_Tag  : constant Profile.Field_Tag := 3;

   procedure Measure
     (Item : Value; Size : out Flyology_Wire.Byte_Count; Status : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic : Sizes.Arithmetic_Status;
      Field_Size : Flyology_Wire.Byte_Count;
   begin
      Size := 0;
      if Item.Code = 0 then
         Status := Flyology_Wire.Codecs.Invalid_Value;
         return;
      end if;

      Profile.Measure_Field
        (Code_Tag, Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Item.Code)), Field_Size, Arithmetic);
      if Arithmetic = Sizes.Computed then
         Size := Field_Size;
         Profile.Measure_Field (Enabled_Tag, 1, Field_Size, Arithmetic);
      end if;
      if Arithmetic = Sizes.Computed then
         Sizes.Accumulate (Size, Field_Size, Arithmetic);
      end if;
      if Arithmetic = Sizes.Overflow then
         Size := 0;
         Status := Flyology_Wire.Codecs.Size_Overflow;
      else
         Status := Flyology_Wire.Codecs.Measured;
      end if;
   end Measure;

   procedure Encode
     (Item    : Value;
      Output  : in out Flyology_Wire.Octet_Array;
      Written : out Flyology_Wire.Octet_Count;
      Status  : out Flyology_Wire.Codecs.Encode_Status)
   is
      Size           : Flyology_Wire.Byte_Count;
      Measure_Result : Flyology_Wire.Codecs.Measure_Status;
      Writer         : Profile.Write_Cursor;
      Nested         : Profile.Write_Cursor;
      Previous       : Profile.Tag_Number := Profile.No_Tag;
      Region         : Profile.Extent;
      Cursor_Result  : Profile.Cursor_Status;
      Write_Result   : Profile.Write_Status;
   begin
      Written := 0;
      Measure (Item, Size, Measure_Result);
      case Measure_Result is
         when Flyology_Wire.Codecs.Invalid_Value =>
            Status := Flyology_Wire.Codecs.Invalid_Value;
            return;

         when Flyology_Wire.Codecs.Size_Overflow =>
            Status := Flyology_Wire.Codecs.Size_Overflow;
            return;

         when Flyology_Wire.Codecs.Measured      =>
            null;
      end case;
      if not Flyology_Wire.Fits_In_Buffer (Size) or else Output'Length < Flyology_Wire.To_Octet_Count (Size)
      then
         Status := Flyology_Wire.Codecs.Destination_Too_Small;
         return;
      end if;

      Region := (Start => 0, Length => Flyology_Wire.To_Octet_Count (Size));
      Profile.Initialize (Writer, Output, Region, Cursor_Result);
      if Cursor_Result /= Profile.Cursor_Ready then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Field_Header
        (Output,
         Writer,
         Previous,
         Code_Tag,
         Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Item.Code)),
         Region,
         Write_Result);
      if Write_Result /= Profile.Wrote then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Initialize (Nested, Output, Region, Cursor_Result);
      if Cursor_Result /= Profile.Cursor_Ready then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Unsigned (Output, Nested, Item.Code, Write_Result);
      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Field_Header (Output, Writer, Previous, Enabled_Tag, 1, Region, Write_Result);
      if Write_Result /= Profile.Wrote then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Initialize (Nested, Output, Region, Cursor_Result);
      if Cursor_Result /= Profile.Cursor_Ready then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Boolean (Output, Nested, Item.Enabled, Write_Result);

      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) or else not Profile.At_End (Writer)
      then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Written := Profile.Consumed (Writer);
      Status := Flyology_Wire.Codecs.Encoded;
   end Encode;

   function Map_Read_Error (Status : Profile.Read_Status) return Flyology_Wire.Codecs.Decode_Status is
   begin
      case Status is
         when Profile.Truncated | Profile.Extent_Outside_Container =>
            return Flyology_Wire.Codecs.Malformed;

         when others                                               =>
            return Flyology_Wire.Codecs.Noncanonical;
      end case;
   end Map_Read_Error;

   procedure Decode
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Item   : out Value;
      Status : out Flyology_Wire.Codecs.Decode_Status)
   is
      Relationship  : constant Compatibility.Schema_Relationship :=
        Compatibility.Classify (Local_Schema, Writer, Accepted_Writers);
      Reader        : Profile.Read_Cursor;
      Nested        : Profile.Read_Cursor;
      Previous      : Profile.Tag_Number := Profile.No_Tag;
      Tag           : Profile.Field_Tag;
      Region        : Profile.Extent;
      Cursor_Result : Profile.Cursor_Status;
      Read_Result   : Profile.Read_Status;
      Candidate     : Value := (Code => 0, Enabled => False);
      Seen_Code     : Boolean := False;
      Seen_Enabled  : Boolean := False;
   begin
      Item := (Code => 1, Enabled => False);
      if Relationship not in Compatibility.Exact | Compatibility.Compatible then
         Status := Flyology_Wire.Codecs.Incompatible;
         return;
      end if;

      Profile.Initialize (Reader, Input);
      while not Profile.At_End (Reader) loop
         Profile.Read_Field_Header (Input, Reader, Previous, Tag, Region, Read_Result);
         if Read_Result /= Profile.Read then
            Status := Map_Read_Error (Read_Result);
            return;
         end if;

         if Tag = Code_Tag then
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Unsigned (Input, Nested, Candidate.Code, Read_Result);
            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then
               Status := Map_Read_Error (Read_Result);
               return;
            end if;
            Seen_Code := True;
         elsif Tag = Enabled_Tag then
            if Relationship = Compatibility.Compatible and then Writer = Older_Schema then
               Status := Flyology_Wire.Codecs.Noncanonical;
               return;
            end if;
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Boolean (Input, Nested, Candidate.Enabled, Read_Result);
            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then
               Status := Map_Read_Error (Read_Result);
               return;
            end if;
            Seen_Enabled := True;
         elsif Tag = Future_Tag
           and then Relationship = Compatibility.Compatible
           and then Writer = Future_Schema
         then
            null;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;

      if not Seen_Code or else Candidate.Code = 0 then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      elsif Writer /= Older_Schema and then not Seen_Enabled then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Item := Candidate;
         Status := Flyology_Wire.Codecs.Decoded;
      end if;
   end Decode;
end Profile_1_Test_Codec;
