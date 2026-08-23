with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Enum_Test_Codec;
with Profile_1_Enumeration_Test_Types;

procedure Generated_Enumeration_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Generated_Profile_1_Enum_Test_Codec;
   package Types renames Profile_1_Enumeration_Test_Types;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Types.Value;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Red_Source     : constant Codec.Value := (Shade => Types.Red);
   Green_Source   : constant Codec.Value := (Shade => Types.Green);
   Red_Expected   : constant Wire.Octet_Array := [1, 1, 1];
   Green_Expected : constant Wire.Octet_Array := [1, 1, 9];
   Unknown_Value  : constant Wire.Octet_Array := [1, 1, 2];
   Overlong_Value : constant Wire.Octet_Array := [1, 2, 16#81#, 0];
   Missing_Field  : constant Wire.Octet_Array (1 .. 0) := [others => 0];
   Output         : Wire.Octet_Array (10 .. 13) := [others => 16#A5#];
   Decoded        : Codec.Value;
   Size           : Wire.Byte_Count;
   Written        : Wire.Octet_Count;
   Measure_Result : Codecs.Measure_Status;
   Encode_Result  : Codecs.Encode_Status;
   Decode_Result  : Codecs.Decode_Status;
begin
   Codec.Contract.Measure (Red_Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 3
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (3),
      "generated enumeration measure or maximum is incorrect");

   Codec.Contract.Encode (Red_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 3 and then Output (10 .. 12) = Red_Expected,
      "generated enumeration used Ada position or representation instead of the wire tag");
   Codec.Contract.Encode (Green_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 3 and then Output (10 .. 12) = Green_Expected,
      "generated enumeration emitted the wrong explicit tag");

   Codec.Contract.Decode (Codec.Local_Schema, Green_Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Green_Source,
      "generated enumeration did not round trip");
   Codec.Contract.Decode (Codec.Local_Schema, Unknown_Value, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = Red_Source,
      "generated enumeration accepted an unknown tag or partially published");
   Codec.Contract.Decode (Codec.Local_Schema, Overlong_Value, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = Red_Source,
      "generated enumeration accepted an overlong value tag");
   Codec.Contract.Decode (Codec.Local_Schema, Missing_Field, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = Red_Source,
      "generated enumeration accepted a missing required field");
end Generated_Enumeration_Codec_Smoke;
