with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Converted_Test_Codec;
with Wire_Shape;

procedure Generated_Converted_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Generated_Profile_1_Converted_Test_Codec;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;
   use type Wire_Shape.Public_Record;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Source         : constant Codec.Value :=
     (Enabled => True, Signed => Wire_Shape.Signed_16'First, Unsigned => Wire_Shape.Unsigned_16'Last);
   Expected       : constant Wire.Octet_Array := [1, 1, 1, 2, 3, 16#FF#, 16#FF#, 3, 3, 3, 16#FF#, 16#FF#, 3];
   Invalid_Signed : constant Wire.Octet_Array := [1, 1, 1, 2, 3, 16#80#, 16#80#, 4, 3, 1, 0];
   Output         : Wire.Octet_Array (10 .. 24) := [others => 16#A5#];
   Decoded        : Codec.Value := (Enabled => False, Signed => 0, Unsigned => 0);
   Size           : Wire.Byte_Count;
   Written        : Wire.Octet_Count;
   Measure_Result : Codecs.Measure_Status;
   Encode_Result  : Codecs.Encode_Status;
   Decode_Result  : Codecs.Decode_Status;
begin
   Codec.Contract.Measure (Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 13
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (13),
      "converted scalar measure or maximum is incorrect");

   Codec.Contract.Encode (Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded
      and then Written = 13
      and then Output (10 .. 22) = Expected
      and then Output (23 .. 24) = [23 => 16#A5#, 24 => 16#A5#],
      "converted scalar codec emitted wrong canonical bytes or extent");

   Codec.Contract.Decode (Codec.Local_Schema, Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Source, "converted scalar codec did not round trip");

   Codec.Contract.Decode (Codec.Local_Schema, Invalid_Signed, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value
      and then Decoded = (Enabled => False, Signed => Wire_Shape.Signed_16'First, Unsigned => 0),
      "converted scalar decode accepted an out-of-schema value or partially published");
end Generated_Converted_Codec_Smoke;
