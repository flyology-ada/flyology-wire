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
   use type Profile.UTF_8_Status;
   use type Profile.Write_Status;
   use type Wire.Byte_Count;
   use type Wire.Octet;
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

   procedure Check_UTF_8 (Bytes : Wire.Octet_Array; Expected : Profile.UTF_8_Status) is
      Result : Profile.UTF_8_Status;
   begin
      Profile.Validate_UTF_8 (Bytes, (Start => 0, Length => Bytes'Length), Result);
      Assert (Result = Expected, "UTF-8 validation returned the wrong status");
   end Check_UTF_8;

   Lent_Calls  : Natural := 0;
   Lent_Length : Wire.Octet_Count := 0;
   Lent_First  : Wire.Octet := 0;

   procedure Record_Extent (Value : Wire.Octet_Array) is
   begin
      Lent_Calls := Lent_Calls + 1;
      Lent_Length := Value'Length;
      if Value'Length > 0 then
         Lent_First := Value (Value'First);
      end if;
   end Record_Extent;

   procedure Lend_Extent is new Profile.Visit_Extent (Record_Extent);

   Output            : Wire.Octet_Array (20 .. 29) := [others => 16#CC#];
   Output_Before     : constant Wire.Octet_Array := Output;
   Small             : Wire.Octet_Array (1 .. 1) := [others => 16#DD#];
   Small_Before      : constant Wire.Octet_Array := Small;
   Writer            : Profile.Write_Cursor;
   Nested_Writer     : Profile.Write_Cursor;
   Reader            : Profile.Read_Cursor;
   Nested_Reader     : Profile.Read_Cursor;
   Cursor_Result     : Profile.Cursor_Status;
   Write_Result      : Profile.Write_Status;
   Read_Result       : Profile.Read_Status;
   Size_Result       : Sizes.Arithmetic_Status;
   Previous          : Profile.Tag_Number;
   Tag               : Profile.Field_Tag;
   Region            : Profile.Extent;
   Decoded_Unsigned  : Interfaces.Unsigned_64;
   Decoded_Signed    : Interfaces.Integer_64;
   Decoded_Boolean   : Boolean;
   Measured          : Wire.Byte_Count;
   Malformed         : Wire.Octet_Array (1 .. 10);
   Ordered_Record    : Wire.Octet_Array (20 .. 26) := [others => 16#CC#];
   Long_Output       : Wire.Octet_Array (30 .. 159) := [others => 16#CC#];
   Empty_Text        : constant Wire.Octet_Array (1 .. 0) := [others => 0];
   Raw_Source        : constant Wire.Octet_Array (40 .. 43) := [16#10#, 16#20#, 16#30#, 16#40#];
   Raw_Output        : Wire.Octet_Array (50 .. 54) := [others => 16#CC#];
   Raw_Output_Before : Wire.Octet_Array (50 .. 54);
   Raw_Value         : Wire.Octet_Array (60 .. 63) := [others => 16#DD#];
   Raw_Value_Before  : Wire.Octet_Array (60 .. 63);
   Extreme_Input     :
     constant Wire.Octet_Array
                (Ada.Streams.Stream_Element_Offset'First .. Ada.Streams.Stream_Element_Offset'First) :=
       [others => 42];
   UTF_8_Result      : Profile.UTF_8_Status;
   UTF_8_Scalars     : Wire.Octet_Count;
begin
   Lend_Extent (Extreme_Input, Profile.Empty_Extent, Cursor_Result);
   Assert
     (Cursor_Result = Profile.Cursor_Ready and then Lent_Calls = 1 and then Lent_Length = 0,
      "empty extent was not lent safely at the index type boundary");
   Output (22) := 16#A5#;
   Lend_Extent (Output, (Start => 2, Length => 1), Cursor_Result);
   Assert
     (Cursor_Result = Profile.Cursor_Ready
      and then Lent_Calls = 2
      and then Lent_Length = 1
      and then Lent_First = 16#A5#,
      "nonempty extent did not lend the selected caller storage");
   Lend_Extent (Output, (Start => Output'Length, Length => 1), Cursor_Result);
   Assert
     (Cursor_Result = Profile.Invalid_Extent and then Lent_Calls = 2, "invalid extent invoked its callback");

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

   Profile.Initialize (Writer, Raw_Output);
   Profile.Write_Octets (Raw_Output, Writer, Raw_Source, 3, Write_Result);
   Assert
     (Write_Result = Profile.Wrote
      and then Profile.Consumed (Writer) = 3
      and then Raw_Output (50 .. 52) = Raw_Source (40 .. 42)
      and then Raw_Output (53 .. 54) = Wire.Octet_Array'(53 .. 54 => 16#CC#),
      "raw octets were not written from arbitrary lower bounds");
   Profile.Initialize (Reader, Raw_Output, (Start => 0, Length => 3), Cursor_Result);
   Profile.Read_Octets (Raw_Output, Reader, Raw_Value, 3, Read_Result);
   Assert
     (Cursor_Result = Profile.Cursor_Ready
      and then Read_Result = Profile.Read
      and then Profile.Consumed (Reader) = 3
      and then Raw_Value (60 .. 62) = Raw_Source (40 .. 42)
      and then Raw_Value (63) = 16#DD#,
      "raw octets were not read into an arbitrary lower bound");

   Profile.Initialize (Writer, Raw_Output);
   Raw_Output_Before := Raw_Output;
   Profile.Write_Octets (Raw_Output, Writer, Raw_Source, 0, Write_Result);
   Assert
     (Write_Result = Profile.Wrote
      and then Profile.Consumed (Writer) = 0
      and then Raw_Output = Raw_Output_Before,
      "zero-length raw write modified its destination");
   Profile.Initialize (Reader, Raw_Output);
   Raw_Value_Before := Raw_Value;
   Profile.Read_Octets (Raw_Output, Reader, Raw_Value, 0, Read_Result);
   Assert
     (Read_Result = Profile.Read and then Profile.Consumed (Reader) = 0 and then Raw_Value = Raw_Value_Before,
      "zero-length raw read modified its destination");

   Profile.Initialize (Writer, Raw_Output, (Start => 0, Length => 2), Cursor_Result);
   Raw_Output_Before := Raw_Output;
   Profile.Write_Octets (Raw_Output, Writer, Raw_Source, 3, Write_Result);
   Assert
     (Cursor_Result = Profile.Cursor_Ready
      and then Write_Result = Profile.Destination_Too_Small
      and then Profile.Consumed (Writer) = 0
      and then Raw_Output = Raw_Output_Before,
      "short raw destination was modified");
   Profile.Initialize (Reader, Raw_Source, (Start => 0, Length => 2), Cursor_Result);
   Raw_Value_Before := Raw_Value;
   Profile.Read_Octets (Raw_Source, Reader, Raw_Value, 3, Read_Result);
   Assert
     (Cursor_Result = Profile.Cursor_Ready
      and then Read_Result = Profile.Truncated
      and then Profile.Consumed (Reader) = 0
      and then Raw_Value = Raw_Value_Before,
      "short raw source modified its destination or cursor");
   Profile.Initialize (Reader, Raw_Source);
   Raw_Value_Before := Raw_Value;
   Profile.Read_Octets (Raw_Source, Reader, Raw_Value (60 .. 61), 3, Read_Result);
   Assert
     (Read_Result = Profile.Destination_Too_Small
      and then Profile.Consumed (Reader) = 0
      and then Raw_Value = Raw_Value_Before,
      "short raw value destination was modified or consumed input");
   Profile.Initialize (Writer, Raw_Output);
   Raw_Output_Before := Raw_Output;
   Profile.Write_Octets (Raw_Output, Writer, Raw_Source (40 .. 41), 3, Write_Result);
   Assert
     (Write_Result = Profile.Destination_Too_Small
      and then Profile.Consumed (Writer) = 0
      and then Raw_Output = Raw_Output_Before,
      "short raw source modified output or its cursor");

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

   Output := [others => 16#CC#];
   Profile.Initialize (Writer, Output);
   Profile.Write_Length_Delimited (Output, Writer, 3, Region, Write_Result);
   Assert
     (Write_Result = Profile.Wrote
      and then Region = (Start => 1, Length => 3)
      and then Profile.Consumed (Writer) = 4
      and then Output (20) = 3,
      "short length-delimited header is not canonical");
   Profile.Initialize (Reader, Output, (Start => 0, Length => 4), Cursor_Result);
   Profile.Read_Length_Delimited (Output, Reader, Region, Read_Result);
   Assert
     (Cursor_Result = Profile.Cursor_Ready
      and then Read_Result = Profile.Read
      and then Region = (Start => 1, Length => 3)
      and then Profile.At_End (Reader),
      "length-delimited extent did not round trip");

   Profile.Initialize (Writer, Long_Output);
   Profile.Write_Length_Delimited (Long_Output, Writer, 128, Region, Write_Result);
   Assert
     (Write_Result = Profile.Wrote
      and then Region = (Start => 2, Length => 128)
      and then Profile.At_End (Writer)
      and then Long_Output (30 .. 31) = [16#80#, 1],
      "multibyte length is not canonical");

   Small := Small_Before;
   Profile.Initialize (Writer, Small);
   Profile.Write_Length_Delimited (Small, Writer, 1, Region, Write_Result);
   Assert
     (Write_Result = Profile.Destination_Too_Small
      and then Profile.Consumed (Writer) = 0
      and then Small = Small_Before,
      "short length-delimited destination was modified");

   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 4, 2 => 0]);
   Profile.Read_Length_Delimited (Wire.Octet_Array'[1 => 4, 2 => 0], Reader, Region, Read_Result);
   Assert
     (Read_Result = Profile.Extent_Outside_Container and then Profile.Consumed (Reader) = 0,
      "out-of-container delimited value was accepted or consumed");
   Profile.Initialize (Reader, Wire.Octet_Array'[1 => 16#80#, 2 => 0]);
   Profile.Read_Length_Delimited (Wire.Octet_Array'[1 => 16#80#, 2 => 0], Reader, Region, Read_Result);
   Assert
     (Read_Result = Profile.Noncanonical and then Profile.Consumed (Reader) = 0,
      "overlong delimited length was accepted or consumed");

   Profile.Measure_Length_Delimited (0, Measured, Size_Result);
   Assert (Size_Result = Sizes.Computed and then Measured = 1, "empty delimited value measurement is wrong");
   Profile.Measure_Length_Delimited (Wire.Byte_Count'Last, Measured, Size_Result);
   Assert
     (Size_Result = Sizes.Overflow and then Measured = 0, "overflowing delimited measurement was accepted");

   Check_UTF_8
     ([1  => 16#41#,
       2  => 16#C2#,
       3  => 16#A2#,
       4  => 16#E2#,
       5  => 16#82#,
       6  => 16#AC#,
       7  => 16#F0#,
       8  => 16#90#,
       9  => 16#8D#,
       10 => 16#88#],
      Profile.Valid_UTF_8);
   Profile.Validate_UTF_8
     ([1  => 16#41#,
       2  => 16#C2#,
       3  => 16#A2#,
       4  => 16#E2#,
       5  => 16#82#,
       6  => 16#AC#,
       7  => 16#F0#,
       8  => 16#90#,
       9  => 16#8D#,
       10 => 16#88#],
      (Start => 0, Length => 10),
      UTF_8_Scalars,
      UTF_8_Result);
   Assert (UTF_8_Result = Profile.Valid_UTF_8 and then UTF_8_Scalars = 4, "UTF-8 scalar count is wrong");
   Check_UTF_8 (Empty_Text, Profile.Valid_UTF_8);
   Check_UTF_8 ([1 => 16#F4#, 2 => 16#8F#, 3 => 16#BF#, 4 => 16#BF#], Profile.Valid_UTF_8);
   Check_UTF_8 ([1 => 16#C0#, 2 => 16#AF#], Profile.Invalid_UTF_8);
   Profile.Validate_UTF_8
     ([1 => 16#41#, 2 => 16#C0#], (Start => 0, Length => 2), UTF_8_Scalars, UTF_8_Result);
   Assert
     (UTF_8_Result = Profile.Invalid_UTF_8 and then UTF_8_Scalars = 0,
      "invalid UTF-8 published a partial scalar count");
   Check_UTF_8 ([1 => 16#C2#, 2 => 16#41#], Profile.Invalid_UTF_8);
   Check_UTF_8 ([1 => 16#F5#, 2 => 16#80#, 3 => 16#80#, 4 => 16#80#], Profile.Invalid_UTF_8);
   Check_UTF_8 ([1 => 16#ED#, 2 => 16#A0#, 3 => 16#80#], Profile.Invalid_UTF_8);
   Check_UTF_8 ([1 => 16#F4#, 2 => 16#90#, 3 => 16#80#, 4 => 16#80#], Profile.Invalid_UTF_8);
   Check_UTF_8 ([1 => 16#E2#, 2 => 16#82#], Profile.Invalid_UTF_8);
   Check_UTF_8 ([1 => 16#80#], Profile.Invalid_UTF_8);
   Profile.Validate_UTF_8 (Small, (Start => 1, Length => 1), UTF_8_Result);
   Assert (UTF_8_Result = Profile.Invalid_UTF_8_Extent, "invalid UTF-8 extent was accepted");

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
