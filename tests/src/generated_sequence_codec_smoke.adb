with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Sequence_Test_Codec;
with Profile_1_Sequence_Test_Types;

procedure Generated_Sequence_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Generated_Profile_1_Sequence_Test_Codec;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Profile_1_Sequence_Test_Types.Value;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Source          : constant Codec.Value := (Items => [1, 128, 300, 1], Length => 3);
   Empty_Source    : constant Codec.Value := (Items => [1, 1, 1, 1], Length => 0);
   Maximum_Source  : constant Codec.Value := (Items => [300, 300, 300, 300], Length => 4);
   Excess_Count    : constant Codec.Value := (Items => [1, 1, 1, 1], Length => 5);
   Invalid_Element : constant Codec.Value := (Items => [0, 1, 1, 1], Length => 1);
   Expected        : constant Wire.Octet_Array := [1, 9, 3, 1, 1, 2, 16#80#, 1, 2, 16#AC#, 2];
   Empty_Expected  : constant Wire.Octet_Array := [1, 1, 0];
   Count_Too_Large : constant Wire.Octet_Array := [1, 1, 5];
   Invalid_Encoded : constant Wire.Octet_Array := [1, 3, 1, 1, 0];
   Truncated       : constant Wire.Octet_Array := [1, 2, 1, 1];
   Trailing        : constant Wire.Octet_Array := [1, 3, 0, 1, 1];
   Output          : Wire.Octet_Array (10 .. 24) := [others => 16#A5#];
   Short           : Wire.Octet_Array (1 .. 10) := [others => 16#CC#];
   Short_Before    : constant Wire.Octet_Array := Short;
   Decoded         : Codec.Value;
   Size            : Wire.Byte_Count;
   Written         : Wire.Octet_Count;
   Measure_Result  : Codecs.Measure_Status;
   Encode_Result   : Codecs.Encode_Status;
   Decode_Result   : Codecs.Decode_Status;
begin
   Codec.Contract.Measure (Source, Size, Measure_Result);
   Assert (Measure_Result = Codecs.Measured and then Size = 11, "generated sequence measure is not exact");
   Codec.Contract.Measure (Maximum_Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 15
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (15),
      "generated sequence maximum is incorrect");
   Codec.Contract.Measure (Excess_Count, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Invalid_Value and then Size = 0,
      "generated sequence measure accepted a count above capacity");
   Codec.Contract.Measure (Invalid_Element, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Invalid_Value and then Size = 0,
      "generated sequence measure accepted an invalid element");

   Codec.Contract.Encode (Source, Short, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Destination_Too_Small and then Written = 0 and then Short = Short_Before,
      "generated sequence short encode modified its destination");
   Codec.Contract.Encode (Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 11 and then Output (10 .. 20) = Expected,
      "generated sequence codec emitted wrong canonical bytes");
   Codec.Contract.Encode (Empty_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 3 and then Output (10 .. 12) = Empty_Expected,
      "generated sequence codec did not encode an empty sequence");

   Codec.Contract.Decode (Codec.Local_Schema, Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Source,
      "generated sequence codec did not round trip");
   Codec.Contract.Decode (Codec.Local_Schema, Count_Too_Large, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = Empty_Source,
      "generated sequence decode accepted a count above capacity or partially published");
   Codec.Contract.Decode (Codec.Local_Schema, Invalid_Encoded, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = Empty_Source,
      "generated sequence decode accepted an invalid element or partially published");
   Codec.Contract.Decode (Codec.Local_Schema, Truncated, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Malformed and then Decoded = Empty_Source,
      "generated sequence decode misclassified a truncated element");
   Codec.Contract.Decode (Codec.Local_Schema, Trailing, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = Empty_Source,
      "generated sequence decode accepted an element beyond its declared count");
end Generated_Sequence_Codec_Smoke;
