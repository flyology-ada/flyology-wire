with Flyology_Wire.Profiles.Tagged_Profile;
with Flyology_Wire.Sizes;
with Interfaces;

package body Generated_Profile_1_Variant_Test_Codec is
   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;
   package Sizes renames Flyology_Wire.Sizes;

   use type Flyology_Wire.Codecs.Schema_Identity;
   use type Flyology_Wire.Codecs.Measure_Status;
   use type Flyology_Wire.Octet_Count;
   use type Interfaces.Unsigned_64;
   use type Profile.Cursor_Status;
   use type Profile.Field_Tag;
   use type Profile.Read_Status;
   use type Profile.Write_Status;
   use type Sizes.Arithmetic_Status;

   Kind_Tag : constant Profile.Field_Tag := 1;
   Kind_Number_Choice_Number_Tag : constant Profile.Field_Tag := 1;
   Kind_Flag_Choice_Flag_Tag : constant Profile.Field_Tag := 1;

   function Encoded_Kind_Tag (Item : Value) return Interfaces.Unsigned_64 is
   begin
      case Item.Kind is
         when Profile_1_Variant_Test_Types.Number_Choice =>
            return 1;
         when Profile_1_Variant_Test_Types.Flag_Choice =>
            return 9;
      end case;
   end Encoded_Kind_Tag;

   Kind_Number_Choice_Binding_Check : constant Value :=
     (Kind => Profile_1_Variant_Test_Types.Number_Choice,
      Number => 0,
      Flag => False);
   pragma Unreferenced (Kind_Number_Choice_Binding_Check);

   Kind_Flag_Choice_Binding_Check : constant Value :=
     (Kind => Profile_1_Variant_Test_Types.Flag_Choice,
      Number => 0,
      Flag => False);
   pragma Unreferenced (Kind_Flag_Choice_Binding_Check);

   Kind_Number_Choice_Number_First_Binding_Check : constant Value :=
     (Kind => Profile_1_Variant_Test_Types.Number_Choice,
      Number => Interfaces.Unsigned_64'First,
      Flag => False);
   pragma Unreferenced (Kind_Number_Choice_Number_First_Binding_Check);

   Kind_Number_Choice_Number_Last_Binding_Check : constant Value :=
     (Kind => Profile_1_Variant_Test_Types.Number_Choice,
      Number => Interfaces.Unsigned_64'Last,
      Flag => False);
   pragma Unreferenced (Kind_Number_Choice_Number_Last_Binding_Check);

   procedure Measure_Kind_Payload
     (Item   : Value;
      Size   : out Flyology_Wire.Byte_Count;
      Status : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic : Sizes.Arithmetic_Status := Sizes.Computed;
      Field_Size : Flyology_Wire.Byte_Count;
   begin
      Size := 0;
      case Item.Kind is
         when Profile_1_Variant_Test_Types.Number_Choice =>
            if Item.Number > 1_000 then
               Size := 0;
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Profile.Measure_Field
              (Kind_Number_Choice_Number_Tag,
               Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Item.Number)),
               Field_Size,
               Arithmetic);
            if Arithmetic = Sizes.Computed then
               Sizes.Accumulate (Size, Field_Size, Arithmetic);
            end if;
         when Profile_1_Variant_Test_Types.Flag_Choice =>
            Profile.Measure_Field
              (Kind_Flag_Choice_Flag_Tag,
               1,
               Field_Size,
               Arithmetic);
            if Arithmetic = Sizes.Computed then
               Sizes.Accumulate (Size, Field_Size, Arithmetic);
            end if;
      end case;
      if Arithmetic = Sizes.Overflow then
         Size := 0;
         Status := Flyology_Wire.Codecs.Size_Overflow;
      else
         Status := Flyology_Wire.Codecs.Measured;
      end if;
   end Measure_Kind_Payload;

   procedure Measure_Kind_Value
     (Item         : Value;
      Size         : out Flyology_Wire.Byte_Count;
      Payload_Size : out Flyology_Wire.Byte_Count;
      Status       : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic : Sizes.Arithmetic_Status := Sizes.Computed;
      Framed_Size : Flyology_Wire.Byte_Count;
   begin
      Size := 0;
      Payload_Size := 0;
      Measure_Kind_Payload (Item, Payload_Size, Status);
      if Status /= Flyology_Wire.Codecs.Measured then
         return;
      end if;
      Size := Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Encoded_Kind_Tag (Item)));
      Profile.Measure_Length_Delimited (Payload_Size, Framed_Size, Arithmetic);
      if Arithmetic = Sizes.Computed then
         Sizes.Accumulate (Size, Framed_Size, Arithmetic);
      end if;
      if Arithmetic = Sizes.Overflow then
         Size := 0;
         Payload_Size := 0;
         Status := Flyology_Wire.Codecs.Size_Overflow;
      end if;
   end Measure_Kind_Value;

   procedure Measure
     (Item   : Value;
      Size   : out Flyology_Wire.Byte_Count;
      Status : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic  : Sizes.Arithmetic_Status;
      Field_Size : Flyology_Wire.Byte_Count;
      Payload_Size : Flyology_Wire.Byte_Count;
      Value_Size : Flyology_Wire.Byte_Count;
   begin
      Size := 0;
      if not Item.Kind'Valid then
         Status := Flyology_Wire.Codecs.Invalid_Value;
         return;
      end if;
      Measure_Kind_Value (Item, Value_Size, Payload_Size, Status);
      if Status /= Flyology_Wire.Codecs.Measured then
         return;
      end if;
      Profile.Measure_Field (Kind_Tag, Value_Size, Field_Size, Arithmetic);
      if Arithmetic = Sizes.Computed then
         Size := Field_Size;
         Status := Flyology_Wire.Codecs.Measured;
      else
         Size := 0;
         Status := Flyology_Wire.Codecs.Size_Overflow;
      end if;
   end Measure;

   procedure Encode
     (Item    : Value;
      Output  : in out Flyology_Wire.Octet_Array;
      Written : out Flyology_Wire.Octet_Count;
      Status  : out Flyology_Wire.Codecs.Encode_Status)
   is
      Size            : Flyology_Wire.Byte_Count;
      Value_Size      : Flyology_Wire.Byte_Count;
      Payload_Size    : Flyology_Wire.Byte_Count;
      Measure_Result  : Flyology_Wire.Codecs.Measure_Status;
      Writer          : Profile.Write_Cursor;
      Nested          : Profile.Write_Cursor;
      Payload_Writer  : Profile.Write_Cursor;
      Scalar_Writer   : Profile.Write_Cursor;
      Previous        : Profile.Tag_Number := Profile.No_Tag;
      Payload_Previous : Profile.Tag_Number := Profile.No_Tag;
      Region          : Profile.Extent;
      Payload_Region  : Profile.Extent;
      Scalar_Region   : Profile.Extent;
      Cursor_Result   : Profile.Cursor_Status;
      Write_Result    : Profile.Write_Status;
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
         when Flyology_Wire.Codecs.Measured =>
            null;
      end case;
      if not Flyology_Wire.Fits_In_Buffer (Size)
        or else Output'Length < Flyology_Wire.To_Octet_Count (Size)
      then
         Status := Flyology_Wire.Codecs.Destination_Too_Small;
         return;
      end if;
      Measure_Kind_Value (Item, Value_Size, Payload_Size, Measure_Result);
      if Measure_Result /= Flyology_Wire.Codecs.Measured then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Region := (Start => 0, Length => Flyology_Wire.To_Octet_Count (Size));
      Profile.Initialize (Writer, Output, Region, Cursor_Result);
      if Cursor_Result /= Profile.Cursor_Ready then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Field_Header
        (Output, Writer, Previous, Kind_Tag, Value_Size, Region, Write_Result);
      if Write_Result /= Profile.Wrote then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Initialize (Nested, Output, Region, Cursor_Result);
      if Cursor_Result /= Profile.Cursor_Ready then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Unsigned (Output, Nested, Encoded_Kind_Tag (Item), Write_Result);
      if Write_Result /= Profile.Wrote then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Write_Length_Delimited
        (Output, Nested, Payload_Size, Payload_Region, Write_Result);
      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Profile.Initialize (Payload_Writer, Output, Payload_Region, Cursor_Result);
      if Cursor_Result /= Profile.Cursor_Ready then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      case Item.Kind is
         when Profile_1_Variant_Test_Types.Number_Choice =>
            Profile.Write_Field_Header
              (Output, Payload_Writer, Payload_Previous, Kind_Number_Choice_Number_Tag,
               Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Item.Number)),
               Scalar_Region, Write_Result);
            if Write_Result /= Profile.Wrote then
               Status := Flyology_Wire.Codecs.Size_Overflow;
               return;
            end if;
            Profile.Initialize (Scalar_Writer, Output, Scalar_Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Size_Overflow;
               return;
            end if;
            Profile.Write_Unsigned (Output, Scalar_Writer, Item.Number, Write_Result);
            if Write_Result /= Profile.Wrote
              or else not Profile.At_End (Scalar_Writer)
            then
               Status := Flyology_Wire.Codecs.Size_Overflow;
               return;
            end if;
         when Profile_1_Variant_Test_Types.Flag_Choice =>
            Profile.Write_Field_Header
              (Output, Payload_Writer, Payload_Previous, Kind_Flag_Choice_Flag_Tag,
               1,
               Scalar_Region, Write_Result);
            if Write_Result /= Profile.Wrote then
               Status := Flyology_Wire.Codecs.Size_Overflow;
               return;
            end if;
            Profile.Initialize (Scalar_Writer, Output, Scalar_Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Size_Overflow;
               return;
            end if;
            Profile.Write_Boolean (Output, Scalar_Writer, Item.Flag, Write_Result);
            if Write_Result /= Profile.Wrote
              or else not Profile.At_End (Scalar_Writer)
            then
               Status := Flyology_Wire.Codecs.Size_Overflow;
               return;
            end if;
      end case;
      if not Profile.At_End (Payload_Writer) or else not Profile.At_End (Writer) then
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
         when others =>
            return Flyology_Wire.Codecs.Noncanonical;
      end case;
   end Map_Read_Error;

   procedure Decode
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Item   : out Value;
      Status : out Flyology_Wire.Codecs.Decode_Status)
   is
      Reader              : Profile.Read_Cursor;
      Nested              : Profile.Read_Cursor;
      Payload_Reader      : Profile.Read_Cursor;
      Scalar_Reader       : Profile.Read_Cursor;
      Previous            : Profile.Tag_Number := Profile.No_Tag;
      Payload_Previous    : Profile.Tag_Number := Profile.No_Tag;
      Tag                 : Profile.Field_Tag;
      Payload_Tag         : Profile.Field_Tag;
      Region              : Profile.Extent;
      Payload_Region      : Profile.Extent;
      Scalar_Region       : Profile.Extent;
      Cursor_Result       : Profile.Cursor_Status;
      Read_Result         : Profile.Read_Status;
      Raw_Kind_Tag : Interfaces.Unsigned_64;
      Candidate           : Value :=
        (Kind => Profile_1_Variant_Test_Types.Number_Choice,
         Number => 0,
         Flag => False);
      Raw_Kind_Number_Choice_Number : Interfaces.Unsigned_64;
      Seen_Kind_Number_Choice_Number : Boolean := False;
      Seen_Kind_Flag_Choice_Flag : Boolean := False;
      Seen_Kind : Boolean := False;
   begin
      Item := (Kind => Profile_1_Variant_Test_Types.Number_Choice, Number => 0, Flag => False);
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
         if Tag = Kind_Tag then
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Unsigned (Input, Nested, Raw_Kind_Tag, Read_Result);
            if Read_Result /= Profile.Read then
               Status := Map_Read_Error (Read_Result);
               return;
            end if;
            Profile.Read_Length_Delimited
              (Input, Nested, Payload_Region, Read_Result);
            if Read_Result /= Profile.Read then
               Status := Map_Read_Error (Read_Result);
               return;
            elsif not Profile.At_End (Nested) then
               Status := Flyology_Wire.Codecs.Noncanonical;
               return;
            end if;
            case Raw_Kind_Tag is
               when 1 =>
                  Candidate.Kind := Profile_1_Variant_Test_Types.Number_Choice;
                  Payload_Previous := Profile.No_Tag;
                  Profile.Initialize
                    (Payload_Reader, Input, Payload_Region, Cursor_Result);
                  if Cursor_Result /= Profile.Cursor_Ready then
                     Status := Flyology_Wire.Codecs.Malformed;
                     return;
                  end if;
                  while not Profile.At_End (Payload_Reader) loop
                     Profile.Read_Field_Header
                       (Input, Payload_Reader, Payload_Previous, Payload_Tag,
                        Scalar_Region, Read_Result);
                     if Read_Result /= Profile.Read then
                        Status := Map_Read_Error (Read_Result);
                        return;
                     end if;
                     if Payload_Tag = Kind_Number_Choice_Number_Tag then
                        Profile.Initialize
                          (Scalar_Reader, Input, Scalar_Region, Cursor_Result);
                        if Cursor_Result /= Profile.Cursor_Ready then
                           Status := Flyology_Wire.Codecs.Malformed;
                           return;
                        end if;
                        Profile.Read_Unsigned
                          (Input, Scalar_Reader, Raw_Kind_Number_Choice_Number, Read_Result);
                        if Read_Result /= Profile.Read
                          or else not Profile.At_End (Scalar_Reader)
                        then
                           Status := Map_Read_Error (Read_Result);
                           return;
                        end if;
                        if Raw_Kind_Number_Choice_Number > 1_000 then
                           Status := Flyology_Wire.Codecs.Invalid_Value;
                           return;
                        end if;
                        Candidate.Number := Raw_Kind_Number_Choice_Number;
                        Seen_Kind_Number_Choice_Number := True;
                     else
                        Status := Flyology_Wire.Codecs.Noncanonical;
                        return;
                     end if;
                  end loop;
                  if not Seen_Kind_Number_Choice_Number then
                     Status := Flyology_Wire.Codecs.Invalid_Value;
                     return;
                  end if;
               when 9 =>
                  Candidate.Kind := Profile_1_Variant_Test_Types.Flag_Choice;
                  Payload_Previous := Profile.No_Tag;
                  Profile.Initialize
                    (Payload_Reader, Input, Payload_Region, Cursor_Result);
                  if Cursor_Result /= Profile.Cursor_Ready then
                     Status := Flyology_Wire.Codecs.Malformed;
                     return;
                  end if;
                  while not Profile.At_End (Payload_Reader) loop
                     Profile.Read_Field_Header
                       (Input, Payload_Reader, Payload_Previous, Payload_Tag,
                        Scalar_Region, Read_Result);
                     if Read_Result /= Profile.Read then
                        Status := Map_Read_Error (Read_Result);
                        return;
                     end if;
                     if Payload_Tag = Kind_Flag_Choice_Flag_Tag then
                        Profile.Initialize
                          (Scalar_Reader, Input, Scalar_Region, Cursor_Result);
                        if Cursor_Result /= Profile.Cursor_Ready then
                           Status := Flyology_Wire.Codecs.Malformed;
                           return;
                        end if;
                        Profile.Read_Boolean
                          (Input, Scalar_Reader, Candidate.Flag, Read_Result);
                        if Read_Result /= Profile.Read
                          or else not Profile.At_End (Scalar_Reader)
                        then
                           Status := Map_Read_Error (Read_Result);
                           return;
                        end if;
                        Seen_Kind_Flag_Choice_Flag := True;
                     else
                        Status := Flyology_Wire.Codecs.Noncanonical;
                        return;
                     end if;
                  end loop;
                  if not Seen_Kind_Flag_Choice_Flag then
                     Status := Flyology_Wire.Codecs.Invalid_Value;
                     return;
                  end if;
               when others =>
                  Status := Flyology_Wire.Codecs.Invalid_Value;
                  return;
            end case;
            Seen_Kind := True;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;
      if not Seen_Kind then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Item := Candidate;
         Status := Flyology_Wire.Codecs.Decoded;
      end if;
   end Decode;
end Generated_Profile_1_Variant_Test_Codec;
