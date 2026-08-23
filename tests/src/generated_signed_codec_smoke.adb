with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Signed_Test_Codec;
with Interfaces;
with Profile_1_Signed_Test_Types;

procedure Generated_Signed_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Generated_Profile_1_Signed_Test_Codec;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Interfaces.Integer_64;
   use type Profile_1_Signed_Test_Types.Value;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Source          : constant Codec.Value := (Count => -4, Enabled => True);
   Upper_Source    : constant Codec.Value := (Count => 7, Enabled => False);
   Invalid_Source  : constant Codec.Value := (Count => -5, Enabled => True);
   Expected        : constant Wire.Octet_Array := [1, 1, 7, 2, 1, 1];
   Upper_Expected  : constant Wire.Octet_Array := [1, 1, 14, 2, 1, 0];
   Invalid_Encoded : constant Wire.Octet_Array := [1, 1, 9, 2, 1, 1];
   Output          : Wire.Octet_Array (10 .. 17) := [others => 16#A5#];
   Decoded         : Codec.Value;
   Size            : Wire.Byte_Count;
   Written         : Wire.Octet_Count;
   Measure_Result  : Codecs.Measure_Status;
   Encode_Result   : Codecs.Encode_Status;
   Decode_Result   : Codecs.Decode_Status;
begin
   Codec.Contract.Measure (Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 6
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (6),
      "generated signed measure or maximum is incorrect");
   Codec.Contract.Measure (Invalid_Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Invalid_Value and then Size = 0,
      "generated signed measure accepted a value below its bound");

   Codec.Contract.Encode (Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded
      and then Written = 6
      and then Output (10 .. 15) = Expected
      and then Output (16 .. 17) = [16 => 16#A5#, 17 => 16#A5#],
      "generated signed codec emitted wrong ZigZag bytes or extent");
   Codec.Contract.Decode (Codec.Local_Schema, Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Source,
      "generated signed lower bound did not round trip");
   Codec.Contract.Decode (Codec.Local_Schema, Upper_Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Upper_Source,
      "generated signed upper bound did not round trip");
   Codec.Contract.Decode (Codec.Local_Schema, Invalid_Encoded, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = (Count => -4, Enabled => False),
      "generated signed decode accepted an out-of-range value or partially published");
end Generated_Signed_Codec_Smoke;
