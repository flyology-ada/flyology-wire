with Flyology_Wire.Profiles.Tagged_Profile;
with Flyology_Wire.Sizes;
with Interfaces;

package body Generated_Profile_1_Text_Test_Codec is
   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;
   package Sizes renames Flyology_Wire.Sizes;

   use type Flyology_Wire.Codecs.Schema_Identity;
   use type Flyology_Wire.Octet_Count;
   use type Flyology_Wire.Codecs.Decode_Status;
   use type Flyology_Wire.Byte_Count;
   use type Interfaces.Unsigned_64;
   use type Profile.UTF_8_Status;
   use type Profile.Cursor_Status;
   use type Profile.Field_Tag;
   use type Profile.Read_Status;
   use type Profile.Write_Status;
   use type Sizes.Arithmetic_Status;

   UTF_8_Tag : constant Profile.Field_Tag := 1;

   UTF_8_Capacity_Binding_Check : constant Value := (UTF_8 => [others => 0], UTF_8_Length => 0);
   pragma
     Compile_Time_Error
       (UTF_8_Capacity_Binding_Check.UTF_8'Length < 8,
        "UTF_8 capacity is below its wire-schema maximum");
   pragma
     Compile_Time_Error
       (UTF_8_Capacity_Binding_Check.UTF_8'First /= 1,
        "UTF_8 lower bound differs from its wire construction bound");

   UTF_8_Length_First_Binding_Check : constant Value :=
     (UTF_8 => [others => 0],
      UTF_8_Length => Interfaces.Unsigned_64'First);
   pragma Unreferenced (UTF_8_Length_First_Binding_Check);

   UTF_8_Length_Last_Binding_Check : constant Value :=
     (UTF_8 => [others => 0],
      UTF_8_Length => Interfaces.Unsigned_64'Last);
   pragma Unreferenced (UTF_8_Length_Last_Binding_Check);

   procedure Measure
     (Item   : Value;
      Size   : out Flyology_Wire.Byte_Count;
      Status : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic : Sizes.Arithmetic_Status;
      Field_Size : Flyology_Wire.Byte_Count;
      UTF_8_Scalar_Count : Flyology_Wire.Octet_Count;
      UTF_8_UTF_8_Status : Profile.UTF_8_Status;
   begin
      Size := 0;
      if Item.UTF_8_Length > 8 or else Item.UTF_8_Length > Interfaces.Unsigned_64 (Item.UTF_8'Length) then
         Status := Flyology_Wire.Codecs.Invalid_Value;
         return;
      end if;

      Profile.Validate_UTF_8 (Item.UTF_8,
                              (Start  => 0,
                               Length => Flyology_Wire.Octet_Count (Item.UTF_8_Length)),
                              UTF_8_Scalar_Count,
                              UTF_8_UTF_8_Status);
      if UTF_8_UTF_8_Status /= Profile.Valid_UTF_8 or else UTF_8_Scalar_Count > 3 then
         Status := Flyology_Wire.Codecs.Invalid_Value;
         return;
      end if;

      Profile.Measure_Field
        (UTF_8_Tag,
         Flyology_Wire.Byte_Count (Item.UTF_8_Length),
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
         UTF_8_Tag,
         Flyology_Wire.Byte_Count (Item.UTF_8_Length),
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
      Profile.Write_Octets (Output, Nested, Item.UTF_8,
                            Flyology_Wire.Octet_Count (Item.UTF_8_Length),
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
      Candidate     : Value := (UTF_8 => [others => 0], UTF_8_Length => 0);
      UTF_8_Scalar_Count : Flyology_Wire.Octet_Count;
      UTF_8_UTF_8_Status : Profile.UTF_8_Status;
      Seen_UTF_8 : Boolean := False;
   begin
      Item := (UTF_8 => [others => 0], UTF_8_Length => 0);
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

         if Tag = UTF_8_Tag then
            if Flyology_Wire.Byte_Count (Region.Length) > 8
              or else Region.Length > Candidate.UTF_8'Length
            then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Profile.Validate_UTF_8
              (Input, Region, UTF_8_Scalar_Count, UTF_8_UTF_8_Status);
            if UTF_8_UTF_8_Status /= Profile.Valid_UTF_8 or else UTF_8_Scalar_Count > 3 then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Octets (Input, Nested, Candidate.UTF_8,
                                 Region.Length, Read_Result);
            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then
               Status := Map_Read_Error (Read_Result);
               return;
            end if;
            Candidate.UTF_8_Length := Interfaces.Unsigned_64 (Region.Length);
            Seen_UTF_8 := True;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;

      if not Seen_UTF_8 then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Item := Candidate;
         Status := Flyology_Wire.Codecs.Decoded;
      end if;
   end Decode;

   procedure Validate_For_Visit
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Status : out Flyology_Wire.Codecs.Decode_Status)
   is
      Reader        : Profile.Read_Cursor;
      Previous      : Profile.Tag_Number := Profile.No_Tag;
      Tag           : Profile.Field_Tag;
      Region        : Profile.Extent;
      Read_Result   : Profile.Read_Status;
      Observed_UTF_8_Scalar_Count : Flyology_Wire.Octet_Count;
      Observed_UTF_8_UTF_8_Status : Profile.UTF_8_Status;
      Seen_UTF_8 : Boolean := False;
   begin
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

         if Tag = UTF_8_Tag then
            if Flyology_Wire.Byte_Count (Region.Length) > 8 then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Profile.Validate_UTF_8
              (Input, Region, Observed_UTF_8_Scalar_Count,
               Observed_UTF_8_UTF_8_Status);
            if Observed_UTF_8_UTF_8_Status /= Profile.Valid_UTF_8 or else Observed_UTF_8_Scalar_Count > 3 then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Seen_UTF_8 := True;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;

      if not Seen_UTF_8 then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Status := Flyology_Wire.Codecs.Decoded;
      end if;
   end Validate_For_Visit;

   procedure Validate_And_Visit
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Status : out Flyology_Wire.Codecs.Decode_Status)
   is
      Reader        : Profile.Read_Cursor;
      Previous      : Profile.Tag_Number := Profile.No_Tag;
      Tag           : Profile.Field_Tag;
      Region        : Profile.Extent;
      Cursor_Result : Profile.Cursor_Status;
      Read_Result   : Profile.Read_Status;
      Valid_Status  : Flyology_Wire.Codecs.Decode_Status;

      procedure Lend_UTF_8 is new
        Profile.Visit_Extent (Visit_UTF_8);
   begin
      Validate_For_Visit (Writer, Input, Valid_Status);
      if Valid_Status /= Flyology_Wire.Codecs.Decoded then
         Status := Valid_Status;
         return;
      end if;

      Profile.Initialize (Reader, Input);
      while not Profile.At_End (Reader) loop
         Profile.Read_Field_Header (Input, Reader, Previous, Tag, Region, Read_Result);
         if Read_Result /= Profile.Read then
            Status := Map_Read_Error (Read_Result);
            return;
         end if;
         if Tag = UTF_8_Tag then
            Lend_UTF_8 (Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;
      Status := Flyology_Wire.Codecs.Decoded;
   end Validate_And_Visit;
end Generated_Profile_1_Text_Test_Codec;
