with Flyology_Wire.Profiles.Tagged_Profile;
with Flyology_Wire.Sizes;
with Interfaces;

package body Generated_Profile_1_Converted_Test_Codec is
   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;
   package Sizes renames Flyology_Wire.Sizes;

   use type Flyology_Wire.Codecs.Schema_Identity;
   use type Flyology_Wire.Octet_Count;
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_64;
   use type Wire_Shape.Signed_16;
   use type Wire_Shape.Unsigned_16;
   use type Profile.Cursor_Status;
   use type Profile.Field_Tag;
   use type Profile.Read_Status;
   use type Profile.Write_Status;
   use type Sizes.Arithmetic_Status;

   Enabled_Tag  : constant Profile.Field_Tag := 1;
   Signed_Tag   : constant Profile.Field_Tag := 2;
   Unsigned_Tag : constant Profile.Field_Tag := 3;

   pragma
     Compile_Time_Error
       (Wire_Shape.Signed_16'First /= -32_768
          or else Wire_Shape.Signed_16'Last /= 32_767,
        "Signed application type differs from its wire-schema range");

   Signed_Minimum_Binding_Check : constant Value :=
     (Enabled => False,
      Signed => Wire_Shape.Signed_16 (-32_768),
      Unsigned => 0);
   pragma Unreferenced (Signed_Minimum_Binding_Check);

   Signed_Maximum_Binding_Check : constant Value :=
     (Enabled => False,
      Signed => Wire_Shape.Signed_16 (32_767),
      Unsigned => 0);
   pragma Unreferenced (Signed_Maximum_Binding_Check);

   pragma
     Compile_Time_Error
       (Wire_Shape.Unsigned_16'First /= 0
          or else Wire_Shape.Unsigned_16'Last /= 65_535,
        "Unsigned application type differs from its wire-schema range");

   Unsigned_Minimum_Binding_Check : constant Value :=
     (Enabled => False,
      Signed => -32_768,
      Unsigned => Wire_Shape.Unsigned_16 (0));
   pragma Unreferenced (Unsigned_Minimum_Binding_Check);

   Unsigned_Maximum_Binding_Check : constant Value :=
     (Enabled => False,
      Signed => -32_768,
      Unsigned => Wire_Shape.Unsigned_16 (65_535));
   pragma Unreferenced (Unsigned_Maximum_Binding_Check);

   procedure Measure
     (Item   : Value;
      Size   : out Flyology_Wire.Byte_Count;
      Status : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic : Sizes.Arithmetic_Status;
      Field_Size : Flyology_Wire.Byte_Count;
   begin
      Size := 0;
      Profile.Measure_Field
        (Enabled_Tag,
         1,
         Field_Size,
         Arithmetic);
      if Arithmetic = Sizes.Computed then
         Sizes.Accumulate (Size, Field_Size, Arithmetic);
      end if;
      if Arithmetic = Sizes.Computed then
         Profile.Measure_Field
           (Signed_Tag,
            Flyology_Wire.Byte_Count
              (Profile.Unsigned_Size (Profile.ZigZag_Encode (Interfaces.Integer_64 (Item.Signed)))),
            Field_Size,
            Arithmetic);
      end if;
      if Arithmetic = Sizes.Computed then
         Sizes.Accumulate (Size, Field_Size, Arithmetic);
      end if;
      if Arithmetic = Sizes.Computed then
         Profile.Measure_Field
           (Unsigned_Tag,
            Flyology_Wire.Byte_Count
              (Profile.Unsigned_Size (Interfaces.Unsigned_64 (Item.Unsigned))),
            Field_Size,
            Arithmetic);
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
      if not Flyology_Wire.Fits_In_Buffer (Size)
        or else Output'Length < Flyology_Wire.To_Octet_Count (Size)
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
         Enabled_Tag,
         1,
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
      Profile.Write_Boolean (Output, Nested, Item.Enabled, Write_Result);
      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Field_Header
        (Output,
         Writer,
         Previous,
         Signed_Tag,
         Flyology_Wire.Byte_Count
           (Profile.Unsigned_Size (Profile.ZigZag_Encode (Interfaces.Integer_64 (Item.Signed)))),
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
      Profile.Write_Signed (Output, Nested, Interfaces.Integer_64 (Item.Signed), Write_Result);
      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Field_Header
        (Output,
         Writer,
         Previous,
         Unsigned_Tag,
         Flyology_Wire.Byte_Count
           (Profile.Unsigned_Size (Interfaces.Unsigned_64 (Item.Unsigned))),
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
      Profile.Write_Unsigned (Output, Nested, Interfaces.Unsigned_64 (Item.Unsigned), Write_Result);
      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      if not Profile.At_End (Writer) then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Written := Profile.Consumed (Writer);
      Status := Flyology_Wire.Codecs.Encoded;
   end Encode;

   function Map_Read_Error
     (Status : Profile.Read_Status) return Flyology_Wire.Codecs.Decode_Status
   is
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
      Reader        : Profile.Read_Cursor;
      Nested        : Profile.Read_Cursor;
      Previous      : Profile.Tag_Number := Profile.No_Tag;
      Tag           : Profile.Field_Tag;
      Region        : Profile.Extent;
      Cursor_Result : Profile.Cursor_Status;
      Read_Result   : Profile.Read_Status;
      Candidate     : Value := (Enabled => False, Signed => -32_768, Unsigned => 0);
      Raw_Signed : Interfaces.Integer_64;
      Raw_Unsigned : Interfaces.Unsigned_64;
      Seen_Enabled  : Boolean := False;
      Seen_Signed   : Boolean := False;
      Seen_Unsigned : Boolean := False;
   begin
      Item := (Enabled => False, Signed => -32_768, Unsigned => 0);
      if Writer /= Local_Schema then
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

         if Tag = Enabled_Tag then
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
         elsif Tag = Signed_Tag then
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Signed (Input, Nested, Raw_Signed, Read_Result);
            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then
               Status := Map_Read_Error (Read_Result);
               return;
            end if;
            if Raw_Signed < -32_768 or else Raw_Signed > 32_767 then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Candidate.Signed := Wire_Shape.Signed_16 (Raw_Signed);
            Seen_Signed := True;
         elsif Tag = Unsigned_Tag then
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Unsigned (Input, Nested, Raw_Unsigned, Read_Result);
            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then
               Status := Map_Read_Error (Read_Result);
               return;
            end if;
            if Raw_Unsigned > 65_535 then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Candidate.Unsigned := Wire_Shape.Unsigned_16 (Raw_Unsigned);
            Seen_Unsigned := True;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;

      if not Seen_Enabled or else not Seen_Signed or else not Seen_Unsigned then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Item := Candidate;
         Status := Flyology_Wire.Codecs.Decoded;
      end if;
   end Decode;
end Generated_Profile_1_Converted_Test_Codec;
