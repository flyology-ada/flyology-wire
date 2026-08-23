with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Defaulted_Test_Codec;
with Profile_1_Defaulted_Test_Types;

procedure Generated_Defaulted_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Generated_Profile_1_Defaulted_Test_Codec;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Profile_1_Defaulted_Test_Types.Value;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Default_Source   : constant Codec.Value := (Code => 0, Enabled => False);
   Code_Source      : constant Codec.Value := (Code => 7, Enabled => False);
   Present_Source   : constant Codec.Value := (Code => 7, Enabled => True);
   Maximum_Source   : constant Codec.Value := (Code => 255, Enabled => True);
   Default_Bytes    : constant Wire.Octet_Array (1 .. 0) := [others => 0];
   Code_Bytes       : constant Wire.Octet_Array := [2, 1, 7];
   Present_Bytes    : constant Wire.Octet_Array := [1, 1, 1, 2, 1, 7];
   Explicit_Default : constant Wire.Octet_Array := [1, 1, 0];
   Explicit_Code    : constant Wire.Octet_Array := [2, 1, 0];
   Output           : Wire.Octet_Array (10 .. 17) := [others => 16#A5#];
   Decoded          : Codec.Value;
   Size             : Wire.Byte_Count;
   Written          : Wire.Octet_Count;
   Measure_Result   : Codecs.Measure_Status;
   Encode_Result    : Codecs.Encode_Status;
   Decode_Result    : Codecs.Decode_Status;
begin
   Codec.Contract.Measure (Default_Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured and then Size = 0,
      "generated defaulted measure did not omit the default");
   Codec.Contract.Measure (Maximum_Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 7
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (7),
      "generated defaulted maximum is incorrect");

   Codec.Contract.Encode (Default_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded
      and then Written = 0
      and then Output =
        [10 => 16#A5#,
         11 => 16#A5#,
         12 => 16#A5#,
         13 => 16#A5#,
         14 => 16#A5#,
         15 => 16#A5#,
         16 => 16#A5#,
         17 => 16#A5#],
      "generated codec explicitly encoded a default");
   Codec.Contract.Encode (Code_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded
      and then Written = 3
      and then Output (10 .. 12) = Code_Bytes,
      "generated codec omitted a nondefault numeric value");
   Codec.Contract.Encode (Present_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 6 and then Output (10 .. 15) = Present_Bytes,
      "generated codec omitted a nondefault value");

   Codec.Contract.Decode (Codec.Local_Schema, Default_Bytes, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Default_Source,
      "generated decode did not construct the omitted default");
   Codec.Contract.Decode (Codec.Local_Schema, Explicit_Default, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 0, Enabled => False),
      "generated decode accepted an explicitly encoded default");
   Codec.Contract.Decode (Codec.Local_Schema, Explicit_Code, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 0, Enabled => False),
      "generated decode accepted an explicitly encoded numeric default");
end Generated_Defaulted_Codec_Smoke;
