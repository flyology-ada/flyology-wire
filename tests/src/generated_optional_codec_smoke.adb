with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Optional_Test_Codec;
with Interfaces;
with Profile_1_Optional_Test_Types;

procedure Generated_Optional_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Generated_Profile_1_Optional_Test_Codec;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Interfaces.Integer_64;
   use type Profile_1_Optional_Test_Types.Value;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   None            : constant Codec.Value := (Number => -1, Has_Number => False);
   Hidden_Invalid  : constant Codec.Value := (Number => 5, Has_Number => False);
   Some_Zero       : constant Codec.Value := (Number => 0, Has_Number => True);
   Some_Upper      : constant Codec.Value := (Number => 1, Has_Number => True);
   Present_Invalid : constant Codec.Value := (Number => 5, Has_Number => True);
   Empty           : constant Wire.Octet_Array (1 .. 0) := [others => 0];
   Zero_Bytes      : constant Wire.Octet_Array := [1, 1, 0];
   Upper_Bytes     : constant Wire.Octet_Array := [1, 1, 2];
   Invalid_Bytes   : constant Wire.Octet_Array := [1, 1, 10];
   Trailing        : constant Wire.Octet_Array := [1, 2, 0, 0];
   Output          : Wire.Octet_Array (10 .. 13) := [others => 16#A5#];
   Decoded         : Codec.Value;
   Size            : Wire.Byte_Count;
   Written         : Wire.Octet_Count;
   Measure_Result  : Codecs.Measure_Status;
   Encode_Result   : Codecs.Encode_Status;
   Decode_Result   : Codecs.Decode_Status;
begin
   Codec.Contract.Measure (None, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured and then Size = 0, "generated optional measure did not omit none");
   Codec.Contract.Measure (Hidden_Invalid, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured and then Size = 0,
      "generated optional measure inspected an absent value");
   Codec.Contract.Measure (Some_Upper, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 3
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (3),
      "generated optional maximum is incorrect");
   Codec.Contract.Measure (Present_Invalid, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Invalid_Value and then Size = 0,
      "generated optional measure accepted an invalid present value");

   Codec.Contract.Encode (None, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded
      and then Written = 0
      and then Output = [10 => 16#A5#, 11 => 16#A5#, 12 => 16#A5#, 13 => 16#A5#],
      "generated optional encode wrote bytes for none");
   Codec.Contract.Encode (Some_Zero, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 3 and then Output (10 .. 12) = Zero_Bytes,
      "generated optional encode collapsed some zero into none");

   Codec.Contract.Decode (Codec.Local_Schema, Empty, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = None,
      "generated optional decode did not construct none");
   Codec.Contract.Decode (Codec.Local_Schema, Zero_Bytes, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Some_Zero,
      "generated optional decode did not preserve some zero");
   Codec.Contract.Decode (Codec.Local_Schema, Upper_Bytes, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Some_Upper,
      "generated optional decode did not preserve the upper bound");
   Codec.Contract.Decode (Codec.Local_Schema, Invalid_Bytes, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = None,
      "generated optional decode accepted an invalid present value or partially published");
   Codec.Contract.Decode (Codec.Local_Schema, Trailing, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = None,
      "generated optional decode accepted trailing scalar bytes");
end Generated_Optional_Codec_Smoke;
