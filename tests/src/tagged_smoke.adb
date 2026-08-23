with Ada.Streams;
with Flyology_Wire.Profiles.Tagged_Profile;
with Flyology_Wire.Sizes;
with Interfaces;

procedure Tagged_Smoke is
   package Wire renames Flyology_Wire;
   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;
   package Sizes renames Flyology_Wire.Sizes;

   use type Ada.Streams.Stream_Element_Array;
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_64;
   use type Sizes.Arithmetic_Status;
   use type Profile.Cursor_Status;
   use type Profile.Extent;
   use type Profile.Read_Status;
   use type Profile.Tag_Number;
   use type Profile.Write_Status;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   procedure Check_Unsigned (Value : Interfaces.Unsigned_64; Bytes : Wire.Octet_Array) is
      Output        : Wire.Octet_Array (10 .. 19) := [others => 16#CC#];
      Writer        : Profile.Write_Cursor;
      Reader        : Profile.Read_Cursor;
      Region        : Profile.Extent;
      Cursor_Result : Profile.Cursor_Status;
      Write_Result  : Profile.Write_Status;
      Read_Result   : Profile.Read_Status;
      Decoded       : Interfaces.Unsigned_64;
   begin
      Profile.Initialize (Writer, Output);
      Profile.Write_Unsigned (Output, Writer, Value, Write_Result);
      Assert (Write_Result = Profile.Wrote, "unsigned value was not written");
      Assert
        (Profile.Consumed (Writer) = Bytes'Length and then Output (10 .. 10 + Bytes'Length - 1) = Bytes,
         "unsigned value has wrong canonical bytes");
      Region := (Start => 0, Length => Profile.Consumed (Writer));
      Profile.Initialize (Reader, Output, Region, Cursor_Result);
      Assert (Cursor_Result = Profile.Cursor_Ready, "encoded unsigned extent is invalid");
      Profile.Read_Unsigned (Output, Reader, Decoded, Read_Result);
      Assert
        (Read_Result = Profile.Read and then Decoded = Value and then Profile.At_End (Reader),
         "unsigned value did not round trip");
   end Check_Unsigned;

   Output           : Wire.Octet_Array (20 .. 29) := [others => 16#CC#];
   Output_Before    : constant Wire.Octet_Array := Output;
   Small            : Wire.Octet_Array (1 .. 1) := [others => 16#DD#];
   Small_Before     : constant Wire.Octet_Array := Small;
   Writer           : Profile.Write_Cursor;
   Nested_Writer    : Profile.Write_Cursor;
   Reader           : Profile.Read_Cursor;
   Nested_Reader    : Profile.Read_Cursor;
   Cursor_Result    : Profile.Cursor_Status;
   Write_Result     : Profile.Write_Status;
   Read_Result      : Profile.Read_Status;
   Size_Result      : Sizes.Arithmetic_Status;
   Previous         : Profile.Tag_Number;
   Tag              : Profile.Field_Tag;
   Region           : Profile.Extent;
   Decoded_Unsigned : Interfaces.Unsigned_64;
   Decoded_Signed   : Interfaces.Integer_64;
   Decoded_Boolean  : Boolean;
   Measured         : Wire.Byte_Count;
   Malformed        : Wire.Octet_Array (1 .. 10);
   Ordered_Record   : Wire.Octet_Array (20 .. 26) := [others => 16#CC#];
begin
   Check_Unsigned (0, [0 => 0]);
   Check_Unsigned (1, [0 => 1]);
   Check_Unsigned (127, [0 => 16#7F#]);
   Check_Unsigned (128, [0 => 16#80#, 1 => 1]);
   Check_Unsigned (300, [0 => 16#AC#, 1 => 2]);
   Check_Unsigned (Interfaces.Unsigned_64'Last, [0 .. 8 => 16#FF#, 9 => 1]);

   Assert
     (Profile.ZigZag_Encode (0) = 0
      and then Profile.ZigZag_Encode (-1) = 1
      and then Profile.ZigZag_Encode (1) = 2
      and then Profile.ZigZag_Encode (Interfaces.Integer_64'First) = Interfaces.Unsigned_64'Last
      and then Profile.ZigZag_Encode (Interfaces.Integer_64'Last) = Interfaces.Unsigned_64'Last - 1,
      "zigzag boundary encoding failed");
   Assert
     (Profile.ZigZag_Decode (Interfaces.Unsigned_64'Last) = Interfaces.Integer_64'First
      and then Profile.ZigZag_Decode (Interfaces.Unsigned_64'Last - 1) = Interfaces.Integer_64'Last,
      "zigzag boundary decoding failed");

   Profile.Initialize (Writer, Output);
   Profile.Write_Signed (Output, Writer, Interfaces.Integer_64'First, Write_Result);
   Assert (Write_Result = Profile.Wrote, "signed boundary was not written");
   Profile.Initialize (Reader, Output, (Start => 0, Length => Profile.Consumed (Writer)), Cursor_Result);
   Profile.Read_Signed (Output, Reader, Decoded_Signed, Read_Result);
   Assert
     (Cursor_Result = Profile.Cursor_Ready
      and then Read_Result = Profile.Read
      and then Decoded_Signed = Interfaces.Integer_64'First,
      "signed boundary did not round trip");

   Profile.Initialize (Writer, Small);
   Profile.Write_Unsigned (Small, Writer, 128, Write_Result);
   Assert
     (Write_Result = Profile.Destination_Too_Small
      and then Profile.Consumed (Writer) = 0
      and then Small = Small_Before,
      "short unsigned destination was modified");

   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 16#80#]);
   Profile.Read_Unsigned (Wire.Octet_Array'[1 => 16#80#], Reader, Decoded_Unsigned, Read_Result);
   Assert
     (Read_Result = Profile.Truncated and then Profile.Consumed (Reader) = 0,
      "truncated varint consumed input");
   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 16#80#, 2 => 0]);
   Profile.Read_Unsigned (Wire.Octet_Array'[1 => 16#80#, 2 => 0], Reader, Decoded_Unsigned, Read_Result);
   Assert
     (Read_Result = Profile.Noncanonical and then Profile.Consumed (Reader) = 0,
      "overlong varint was accepted or consumed");

   Malformed := [1 .. 9 => 16#FF#, 10 => 2];
   Profile.Initialize (Reader, Malformed);
   Profile.Read_Unsigned (Malformed, Reader, Decoded_Unsigned, Read_Result);
   Assert
     (Read_Result = Profile.Value_Overflow and then Profile.Consumed (Reader) = 0,
      "overflowing varint was accepted or consumed");
   Malformed := [others => 16#80#];
   Profile.Initialize (Reader, Malformed);
   Profile.Read_Unsigned (Malformed, Reader, Decoded_Unsigned, Read_Result);
   Assert
     (Read_Result = Profile.Value_Overflow and then Profile.Consumed (Reader) = 0,
      "continued tenth varint byte was accepted or consumed");

   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 2]);
   Profile.Read_Boolean (Wire.Octet_Array'[1 => 2], Reader, Decoded_Boolean, Read_Result);
   Assert
     (Read_Result = Profile.Invalid_Boolean and then Profile.Consumed (Reader) = 0,
      "invalid boolean was accepted or consumed");

   Profile.Initialize (Writer, Ordered_Record);
   Previous := Profile.No_Tag;
   Profile.Write_Field_Header (Ordered_Record, Writer, Previous, 1, 1, Region, Write_Result);
   Assert
     (Write_Result = Profile.Wrote and then Region = (Start => 2, Length => 1),
      "first field header was not written");
   Profile.Initialize (Nested_Writer, Ordered_Record, Region, Cursor_Result);
   Profile.Write_Boolean (Ordered_Record, Nested_Writer, True, Write_Result);
   Assert
     (Cursor_Result = Profile.Cursor_Ready
      and then Write_Result = Profile.Wrote
      and then Profile.At_End (Nested_Writer),
      "first field value was not written");
   Profile.Write_Field_Header (Ordered_Record, Writer, Previous, 300, 1, Region, Write_Result);
   Profile.Initialize (Nested_Writer, Ordered_Record, Region, Cursor_Result);
   Profile.Write_Boolean (Ordered_Record, Nested_Writer, False, Write_Result);
   Assert
     (Ordered_Record = [20 => 1, 21 => 1, 22 => 1, 23 => 16#AC#, 24 => 2, 25 => 1, 26 => 0]
      and then Profile.At_End (Writer),
      "ordered record has wrong canonical bytes");

   Profile.Initialize (Reader, Ordered_Record);
   Previous := Profile.No_Tag;
   Profile.Read_Field_Header (Ordered_Record, Reader, Previous, Tag, Region, Read_Result);
   Profile.Initialize (Nested_Reader, Ordered_Record, Region, Cursor_Result);
   Profile.Read_Boolean (Ordered_Record, Nested_Reader, Decoded_Boolean, Read_Result);
   Assert
     (Tag = 1 and then Decoded_Boolean and then Profile.At_End (Nested_Reader),
      "first record field did not decode");
   Profile.Read_Field_Header (Ordered_Record, Reader, Previous, Tag, Region, Read_Result);
   Profile.Initialize (Nested_Reader, Ordered_Record, Region, Cursor_Result);
   Profile.Read_Boolean (Ordered_Record, Nested_Reader, Decoded_Boolean, Read_Result);
   Assert
     (Tag = 300
      and then not Decoded_Boolean
      and then Profile.At_End (Nested_Reader)
      and then Profile.At_End (Reader),
      "second record field did not decode");

   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 1, 2 => 0, 3 => 1, 4 => 0]);
   Previous := Profile.No_Tag;
   Profile.Read_Field_Header
     (Wire.Octet_Array'[1 => 1, 2 => 0, 3 => 1, 4 => 0], Reader, Previous, Tag, Region, Read_Result);
   Profile.Read_Field_Header
     (Wire.Octet_Array'[1 => 1, 2 => 0, 3 => 1, 4 => 0], Reader, Previous, Tag, Region, Read_Result);
   Assert
     (Read_Result = Profile.Tag_Order_Error and then Profile.Consumed (Reader) = 2 and then Previous = 1,
      "duplicate field tag was accepted or consumed");

   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 1, 2 => 5, 3 => 0]);
   Previous := Profile.No_Tag;
   Profile.Read_Field_Header
     (Wire.Octet_Array'[1 => 1, 2 => 5, 3 => 0], Reader, Previous, Tag, Region, Read_Result);
   Assert
     (Read_Result = Profile.Extent_Outside_Container
      and then Profile.Consumed (Reader) = 0
      and then Previous = Profile.No_Tag,
      "out-of-container field extent was accepted or consumed");

   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 0, 2 => 0]);
   Previous := Profile.No_Tag;
   Profile.Read_Field_Header (Wire.Octet_Array'[1 => 0, 2 => 0], Reader, Previous, Tag, Region, Read_Result);
   Assert
     (Read_Result = Profile.Invalid_Tag
      and then Profile.Consumed (Reader) = 0
      and then Previous = Profile.No_Tag,
      "zero field tag was accepted or consumed");

   Profile.Initialize
     (Reader, Wire.Octet_Array'[1 => 16#80#, 2 => 16#80#, 3 => 16#80#, 4 => 16#80#, 5 => 2, 6 => 0]);
   Previous := Profile.No_Tag;
   Profile.Read_Field_Header
     (Wire.Octet_Array'[1 => 16#80#, 2 => 16#80#, 3 => 16#80#, 4 => 16#80#, 5 => 2, 6 => 0],
      Reader,
      Previous,
      Tag,
      Region,
      Read_Result);
   Assert
     (Read_Result = Profile.Invalid_Tag
      and then Profile.Consumed (Reader) = 0
      and then Previous = Profile.No_Tag,
      "out-of-range field tag was accepted or consumed");

   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 1, 2 => 16#80#]);
   Previous := Profile.No_Tag;
   Profile.Read_Field_Header
     (Wire.Octet_Array'[1 => 1, 2 => 16#80#], Reader, Previous, Tag, Region, Read_Result);
   Assert
     (Read_Result = Profile.Truncated
      and then Profile.Consumed (Reader) = 0
      and then Previous = Profile.No_Tag,
      "truncated field length consumed its header");

   Output := Output_Before;
   Profile.Initialize (Writer, Output);
   Previous := Profile.No_Tag;
   Profile.Write_Field_Header (Output, Writer, Previous, Profile.No_Tag, 0, Region, Write_Result);
   Assert
     (Write_Result = Profile.Invalid_Tag
      and then Profile.Consumed (Writer) = 0
      and then Previous = Profile.No_Tag
      and then Output = Output_Before,
      "zero field tag was written");

   Previous := 2;
   Profile.Write_Field_Header (Output, Writer, Previous, 1, 0, Region, Write_Result);
   Assert
     (Write_Result = Profile.Tag_Order_Error
      and then Profile.Consumed (Writer) = 0
      and then Previous = 2
      and then Output = Output_Before,
      "decreasing field tag was written");

   Output := [others => 16#CC#];
   Profile.Initialize (Writer, Output);
   Previous := Profile.No_Tag;
   Profile.Write_Field_Header (Output, Writer, Previous, Profile.Max_Field_Tag, 0, Region, Write_Result);
   Assert
     (Write_Result = Profile.Wrote
      and then Profile.Consumed (Writer) = 6
      and then Output (20 .. 25) = [16#FF#, 16#FF#, 16#FF#, 16#FF#, 1, 0],
      "maximum field tag has wrong canonical header");

   Profile.Measure_Field (1, 1, Measured, Size_Result);
   Assert (Size_Result = Sizes.Computed and then Measured = 3, "field measurement is not exact");
   Profile.Measure_Field (1, Wire.Byte_Count'Last, Measured, Size_Result);
   Assert (Size_Result = Sizes.Overflow and then Measured = 0, "overflowing field measurement was accepted");

   Profile.Initialize (Nested_Reader, Small, (Start => 1, Length => 1), Cursor_Result);
   Assert (Cursor_Result = Profile.Invalid_Extent, "invalid nested extent was accepted");

   Profile.Initialize (Writer, Output);
   Profile.Write_Unsigned (Small, Writer, 1, Write_Result);
   Assert
     (Write_Result = Profile.Destination_Too_Small and then Small = Small_Before,
      "cursor was unsafely reused with a smaller output");

   Profile.Initialize (Reader, Output);
   Profile.Read_Unsigned (Small, Reader, Decoded_Unsigned, Read_Result);
   Assert
     (Read_Result = Profile.Extent_Outside_Container and then Profile.Consumed (Reader) = 0,
      "read cursor was unsafely reused with a smaller input");
end Tagged_Smoke;
