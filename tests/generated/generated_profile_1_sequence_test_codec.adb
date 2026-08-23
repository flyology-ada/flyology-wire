with Flyology_Wire.Profiles.Tagged_Profile;
with Flyology_Wire.Sizes;
with Interfaces;

package body Generated_Profile_1_Sequence_Test_Codec is
   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;
   package Sizes renames Flyology_Wire.Sizes;

   use type Flyology_Wire.Codecs.Schema_Identity;
   use type Flyology_Wire.Octet_Count;
   use type Flyology_Wire.Codecs.Measure_Status;
   use type Interfaces.Unsigned_64;
   use type Profile.Cursor_Status;
   use type Profile.Field_Tag;
   use type Profile.Read_Status;
   use type Profile.Write_Status;
   use type Sizes.Arithmetic_Status;

   Items_Tag : constant Profile.Field_Tag := 1;

   Items_Capacity_Binding_Check : constant Value := (Items => [others => 1], Length => 0);
   pragma
     Compile_Time_Error
       (Items_Capacity_Binding_Check.Items'Length < 4,
        "Items capacity is below its wire-schema maximum");
   pragma
     Compile_Time_Error
       (Items_Capacity_Binding_Check.Items'First /= 1,
        "Items lower bound differs from its wire construction bound");

   Length_First_Binding_Check : constant Value :=
     (Items => [others => 1],
      Length => Interfaces.Unsigned_64'First);
   pragma Unreferenced (Length_First_Binding_Check);

   Length_Last_Binding_Check : constant Value :=
     (Items => [others => 1],
      Length => Interfaces.Unsigned_64'Last);
   pragma Unreferenced (Length_Last_Binding_Check);

   Items_First_Binding_Check : constant Value :=
     (Items => [others => Interfaces.Unsigned_64'First],
      Length => 0);
   pragma Unreferenced (Items_First_Binding_Check);

   Items_Last_Binding_Check : constant Value :=
     (Items => [others => Interfaces.Unsigned_64'Last],
      Length => 0);
   pragma Unreferenced (Items_Last_Binding_Check);

   procedure Measure_Items_Value
     (Item   : Value;
      Size   : out Flyology_Wire.Byte_Count;
      Status : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic  : Sizes.Arithmetic_Status := Sizes.Computed;
      Element_Size : Flyology_Wire.Byte_Count;
      Remaining   : Interfaces.Unsigned_64 := Item.Length;
   begin
      Size := Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Item.Length));
      if Item.Length > 4 or else Item.Length > Interfaces.Unsigned_64 (Item.Items'Length) then
         Size := 0;
         Status := Flyology_Wire.Codecs.Invalid_Value;
         return;
      end if;
      for Element of Item.Items loop
         exit when Remaining = 0 or else Arithmetic /= Sizes.Computed;
         if Element < 1 or else Element > 300 then
            Size := 0;
            Status := Flyology_Wire.Codecs.Invalid_Value;
            return;
         end if;
         Profile.Measure_Length_Delimited
           (Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Element)), Element_Size, Arithmetic);
         if Arithmetic = Sizes.Computed then
            Sizes.Accumulate (Size, Element_Size, Arithmetic);
         end if;
         Remaining := Remaining - 1;
      end loop;
      if Arithmetic = Sizes.Overflow then
         Size := 0;
         Status := Flyology_Wire.Codecs.Size_Overflow;
      elsif Remaining /= 0 then
         Size := 0;
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Status := Flyology_Wire.Codecs.Measured;
      end if;
   end Measure_Items_Value;

   procedure Measure
     (Item   : Value;
      Size   : out Flyology_Wire.Byte_Count;
      Status : out Flyology_Wire.Codecs.Measure_Status)
   is
      Arithmetic : Sizes.Arithmetic_Status;
      Field_Size : Flyology_Wire.Byte_Count;
      Items_Value_Size : Flyology_Wire.Byte_Count;
      Items_Measure_Status : Flyology_Wire.Codecs.Measure_Status;
   begin
      Size := 0;
      Measure_Items_Value (Item, Items_Value_Size, Items_Measure_Status);
      if Items_Measure_Status /= Flyology_Wire.Codecs.Measured then
         Size := 0;
         Status := Items_Measure_Status;
         return;
      end if;
      Profile.Measure_Field
        (Items_Tag,
         Items_Value_Size,
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
      Items_Value_Size : Flyology_Wire.Byte_Count;
      Items_Measure_Status : Flyology_Wire.Codecs.Measure_Status;
      Items_Element_Writer : Profile.Write_Cursor;
      Items_Element_Region : Profile.Extent;
      Items_Remaining : Interfaces.Unsigned_64;
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
      Measure_Items_Value
        (Item, Items_Value_Size, Items_Measure_Status);
      case Items_Measure_Status is
         when Flyology_Wire.Codecs.Invalid_Value =>
            Status := Flyology_Wire.Codecs.Invalid_Value;
            return;
         when Flyology_Wire.Codecs.Size_Overflow =>
            Status := Flyology_Wire.Codecs.Size_Overflow;
            return;
         when Flyology_Wire.Codecs.Measured =>
            null;
      end case;
      Profile.Write_Field_Header
        (Output,
         Writer,
         Previous,
         Items_Tag,
         Items_Value_Size,
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
      Profile.Write_Unsigned (Output, Nested, Item.Length, Write_Result);
      if Write_Result /= Profile.Wrote then
         Status := Flyology_Wire.Codecs.Size_Overflow;
         return;
      end if;
      Items_Remaining := Item.Length;
      for Element of Item.Items loop
         exit when Items_Remaining = 0;
         Profile.Write_Length_Delimited
           (Output,
            Nested,
            Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Element)),
            Items_Element_Region,
            Write_Result);
         if Write_Result /= Profile.Wrote then
            Status := Flyology_Wire.Codecs.Size_Overflow;
            return;
         end if;
         Profile.Initialize
           (Items_Element_Writer,
            Output,
            Items_Element_Region,
            Cursor_Result);
         if Cursor_Result /= Profile.Cursor_Ready then
            Status := Flyology_Wire.Codecs.Size_Overflow;
            return;
         end if;
         Profile.Write_Unsigned (Output, Items_Element_Writer, Element, Write_Result);
         if Write_Result /= Profile.Wrote
           or else not Profile.At_End (Items_Element_Writer)
         then
            Status := Flyology_Wire.Codecs.Size_Overflow;
            return;
         end if;
         Items_Remaining := Items_Remaining - 1;
      end loop;
      if Items_Remaining /= 0 or else not Profile.At_End (Nested) then
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
      Candidate     : Value := (Items => [others => 1], Length => 0);
      Raw_Items_Length : Interfaces.Unsigned_64;
      Items_Element_Reader : Profile.Read_Cursor;
      Items_Element_Region : Profile.Extent;
      Items_Remaining : Interfaces.Unsigned_64;
      Raw_Items_Element : Interfaces.Unsigned_64;
      Seen_Items : Boolean := False;
   begin
      Item := (Items => [others => 1], Length => 0);
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

         if Tag = Items_Tag then
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Unsigned (Input, Nested, Raw_Items_Length, Read_Result);
            if Read_Result /= Profile.Read then
               Status := Map_Read_Error (Read_Result);
               return;
            end if;
            if Raw_Items_Length > 4
              or else Raw_Items_Length > Interfaces.Unsigned_64 (Candidate.Items'Length)
            then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Candidate.Length := Raw_Items_Length;
            Items_Remaining := Raw_Items_Length;
            for Element of Candidate.Items loop
               exit when Items_Remaining = 0;
               Profile.Read_Length_Delimited
                 (Input, Nested, Items_Element_Region, Read_Result);
               if Read_Result /= Profile.Read then
                  Status := Map_Read_Error (Read_Result);
                  return;
               end if;
               Profile.Initialize
                 (Items_Element_Reader,
                  Input,
                  Items_Element_Region,
                  Cursor_Result);
               if Cursor_Result /= Profile.Cursor_Ready then
                  Status := Flyology_Wire.Codecs.Malformed;
                  return;
               end if;
               Profile.Read_Unsigned (Input, Items_Element_Reader, Raw_Items_Element, Read_Result);
               if Read_Result /= Profile.Read
                 or else not Profile.At_End (Items_Element_Reader)
               then
                  Status := Map_Read_Error (Read_Result);
                  return;
               end if;
               if Raw_Items_Element < 1 or else Raw_Items_Element > 300 then
                  Status := Flyology_Wire.Codecs.Invalid_Value;
                  return;
               end if;
               Element := Raw_Items_Element;
               Items_Remaining := Items_Remaining - 1;
            end loop;
            if Items_Remaining /= 0 then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            if not Profile.At_End (Nested) then
               Status := Flyology_Wire.Codecs.Noncanonical;
               return;
            end if;
            Seen_Items := True;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;

      if not Seen_Items then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Item := Candidate;
         Status := Flyology_Wire.Codecs.Decoded;
      end if;
   end Decode;
end Generated_Profile_1_Sequence_Test_Codec;
