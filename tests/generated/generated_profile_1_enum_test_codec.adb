with Flyology_Wire.Profiles.Tagged_Profile;
with Flyology_Wire.Sizes;
with Interfaces;

package body Generated_Profile_1_Enum_Test_Codec is
   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;
   package Sizes renames Flyology_Wire.Sizes;

   use type Flyology_Wire.Codecs.Schema_Identity;
   use type Flyology_Wire.Octet_Count;
   use type Profile.Cursor_Status;
   use type Profile.Field_Tag;
   use type Profile.Read_Status;
   use type Profile.Write_Status;
   use type Sizes.Arithmetic_Status;

   Shade_Tag : constant Profile.Field_Tag := 1;

   function Encoded_Shade_Tag (Item : Value) return Interfaces.Unsigned_64 is
   begin
      case Item.Shade is
         when Profile_1_Enumeration_Test_Types.Red =>
            return 1;
         when Profile_1_Enumeration_Test_Types.Green =>
            return 9;
      end case;
   end Encoded_Shade_Tag;

   Shade_Red_Binding_Check : constant Value := (Shade => Profile_1_Enumeration_Test_Types.Red);
   pragma Unreferenced (Shade_Red_Binding_Check);

   Shade_Green_Binding_Check : constant Value := (Shade => Profile_1_Enumeration_Test_Types.Green);
   pragma Unreferenced (Shade_Green_Binding_Check);

   procedure Measure
     (Item   : Value;
      Size   : out Flyology_Wire.Byte_Count;
      Status : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic : Sizes.Arithmetic_Status;
      Field_Size : Flyology_Wire.Byte_Count;
   begin
      Size := 0;
      if not Item.Shade'Valid then
         Status := Flyology_Wire.Codecs.Invalid_Value;
         return;
      end if;

      Profile.Measure_Field
        (Shade_Tag,
         Flyology_Wire.Byte_Count
           (Profile.Unsigned_Size (Encoded_Shade_Tag (Item))),
         Field_Size,
         Arithmetic);
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
         Shade_Tag,
         Flyology_Wire.Byte_Count
           (Profile.Unsigned_Size (Encoded_Shade_Tag (Item))),
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
      Profile.Write_Unsigned (Output, Nested, Encoded_Shade_Tag (Item),
                              Write_Result);
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
      Candidate     : Value := (Shade => Profile_1_Enumeration_Test_Types.Red);
      Raw_Shade : Interfaces.Unsigned_64;
      Seen_Shade : Boolean := False;
   begin
      Item := (Shade => Profile_1_Enumeration_Test_Types.Red);
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

         if Tag = Shade_Tag then
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Unsigned (Input, Nested, Raw_Shade, Read_Result);
            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then
               Status := Map_Read_Error (Read_Result);
               return;
            end if;
            case Raw_Shade is
               when 1 =>
                  Candidate.Shade := Profile_1_Enumeration_Test_Types.Red;
               when 9 =>
                  Candidate.Shade := Profile_1_Enumeration_Test_Types.Green;
               when others =>
                  Status := Flyology_Wire.Codecs.Invalid_Value;
                  return;
            end case;
            Seen_Shade := True;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;

      if not Seen_Shade then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Item := Candidate;
         Status := Flyology_Wire.Codecs.Decoded;
      end if;
   end Decode;
end Generated_Profile_1_Enum_Test_Codec;
