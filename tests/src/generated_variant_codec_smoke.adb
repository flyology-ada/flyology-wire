with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Variant_Test_Codec;
with Interfaces;
with Profile_1_Variant_Test_Types;

procedure Generated_Variant_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Generated_Profile_1_Variant_Test_Codec;
   package Types renames Profile_1_Variant_Test_Types;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Interfaces.Unsigned_64;
   use type Types.Choice_Kind;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Number_Source   : constant Codec.Value := (Kind => Types.Number_Choice, Number => 300, Flag => True);
   Flag_Source     : constant Codec.Value := (Kind => Types.Flag_Choice, Number => 1_001, Flag => True);
   Invalid_Number  : constant Codec.Value := (Kind => Types.Number_Choice, Number => 1_001, Flag => False);
   Number_Expected : constant Wire.Octet_Array := [1, 6, 1, 4, 1, 2, 16#AC#, 2];
   Flag_Expected   : constant Wire.Octet_Array := [1, 5, 9, 3, 1, 1, 1];
   Unknown_Choice  : constant Wire.Octet_Array := [1, 2, 2, 0];
   Missing_Payload : constant Wire.Octet_Array := [1, 2, 1, 0];
   Unknown_Field   : constant Wire.Octet_Array := [1, 5, 1, 3, 2, 1, 0];
   Trailing_Value  : constant Wire.Octet_Array := [1, 3, 1, 0, 0];
   Overlong_Tag    : constant Wire.Octet_Array := [1, 3, 16#81#, 0, 0];
   Invalid_Boolean : constant Wire.Octet_Array := [1, 5, 9, 3, 1, 1, 2];
   Output          : Wire.Octet_Array (10 .. 17) := [others => 16#A5#];
   Decoded         : Codec.Value;
   Size            : Wire.Byte_Count;
   Written         : Wire.Octet_Count;
   Measure_Result  : Codecs.Measure_Status;
   Encode_Result   : Codecs.Encode_Status;
   Decode_Result   : Codecs.Decode_Status;
begin
   Codec.Contract.Measure (Number_Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 8
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (8),
      "generated variant measure or maximum is incorrect");

   Codec.Contract.Encode (Number_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 8 and then Output = Number_Expected,
      "generated number alternative bytes are incorrect");
   Codec.Contract.Encode (Flag_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 7 and then Output (10 .. 16) = Flag_Expected,
      "generated flag alternative bytes are incorrect");

   Codec.Contract.Measure (Invalid_Number, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Invalid_Value and then Size = 0,
      "generated variant measure accepted an invalid selected payload");
   Output := [others => 16#A5#];
   Codec.Contract.Encode (Invalid_Number, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Invalid_Value
      and then Written = 0
      and then Output = [16#A5#, 16#A5#, 16#A5#, 16#A5#, 16#A5#, 16#A5#, 16#A5#, 16#A5#],
      "invalid selected payload modified output");

   Codec.Contract.Decode (Codec.Local_Schema, Number_Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded
      and then Decoded.Kind = Types.Number_Choice
      and then Decoded.Number = 300
      and then not Decoded.Flag,
      "number alternative did not round trip with hidden storage reset");
   Codec.Contract.Decode (Codec.Local_Schema, Flag_Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded
      and then Decoded.Kind = Types.Flag_Choice
      and then Decoded.Number = 0
      and then Decoded.Flag,
      "flag alternative did not round trip with hidden storage reset");

   Codec.Contract.Decode (Codec.Local_Schema, Unknown_Choice, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value
      and then Decoded.Kind = Types.Number_Choice
      and then Decoded.Number = 0,
      "generated variant accepted a reserved selector or partially published");
   Codec.Contract.Decode (Codec.Local_Schema, Missing_Payload, Decoded, Decode_Result);
   Assert (Decode_Result = Codecs.Invalid_Value, "generated variant accepted a missing payload field");
   Codec.Contract.Decode (Codec.Local_Schema, Unknown_Field, Decoded, Decode_Result);
   Assert (Decode_Result = Codecs.Noncanonical, "generated variant accepted an unknown payload field");
   Codec.Contract.Decode (Codec.Local_Schema, Trailing_Value, Decoded, Decode_Result);
   Assert (Decode_Result = Codecs.Noncanonical, "generated variant accepted trailing value octets");
   Codec.Contract.Decode (Codec.Local_Schema, Overlong_Tag, Decoded, Decode_Result);
   Assert (Decode_Result = Codecs.Noncanonical, "generated variant accepted an overlong selector");
   Codec.Contract.Decode (Codec.Local_Schema, Invalid_Boolean, Decoded, Decode_Result);
   Assert (Decode_Result = Codecs.Noncanonical, "generated variant accepted an invalid Boolean");
end Generated_Variant_Codec_Smoke;
