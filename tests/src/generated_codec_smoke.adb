with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Test_Codec;
with Interfaces;
with Profile_1_Test_Codec;
with Profile_1_Test_Types;

procedure Generated_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Generated renames Generated_Profile_1_Test_Codec;
   package Handwritten renames Profile_1_Test_Codec;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Codec_Descriptor;
   use type Codecs.Measure_Status;
   use type Codecs.Schema_Identity;
   use type Profile_1_Test_Types.Value;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Source           : constant Generated.Value := (Code => 300, Enabled => True);
   Maximum_Source   : constant Generated.Value := (Code => Interfaces.Unsigned_64'Last, Enabled => True);
   Invalid_Source   : constant Generated.Value := (Code => 0, Enabled => True);
   Expected         : constant Wire.Octet_Array := [1, 2, 16#AC#, 2, 2, 1, 1];
   Missing_Field    : constant Wire.Octet_Array := [1, 1, 1];
   Invalid_Boolean  : constant Wire.Octet_Array := [1, 1, 1, 2, 1, 2];
   Unknown_Field    : constant Wire.Octet_Array := [1, 1, 1, 2, 1, 1, 3, 0];
   Oversized_Future : constant Wire.Octet_Array := [1, 1, 1, 2, 1, 1, 3, 2, 16#AA#, 16#BB#];
   Generated_Output : Wire.Octet_Array (20 .. 29) := [others => 16#A5#];
   Hand_Output      : Wire.Octet_Array (20 .. 29) := [others => 16#5A#];
   Short            : Wire.Octet_Array (1 .. 6) := [others => 16#CC#];
   Short_Before     : constant Wire.Octet_Array := Short;
   Decoded          : Generated.Value;
   Size             : Wire.Byte_Count;
   Written          : Wire.Octet_Count;
   Hand_Written     : Wire.Octet_Count;
   Measure_Result   : Codecs.Measure_Status;
   Encode_Result    : Codecs.Encode_Status;
   Hand_Result      : Codecs.Encode_Status;
   Decode_Result    : Codecs.Decode_Status;
begin
   Assert (Generated.Local_Schema = Handwritten.Local_Schema, "generated schema identity drifted");
   Assert
     (Generated.Value_Descriptor = Handwritten.Value_Descriptor,
      "generated descriptor drifted from the reviewed fixture");
   Assert
     (Generated.Accepted_Writer_1_Schema = Handwritten.Older_Schema
      and then Generated.Accepted_Writer_2_Schema = Handwritten.Future_Schema,
      "generated compatibility identities drifted");

   Generated.Contract.Measure (Source, Size, Measure_Result);
   Assert (Measure_Result = Codecs.Measured and then Size = 7, "generated measure is not exact");
   Generated.Contract.Measure (Maximum_Source, Size, Measure_Result);
   Assert (Measure_Result = Codecs.Measured and then Size = 15, "generated maximum is incorrect");
   Generated.Contract.Measure (Invalid_Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Invalid_Value and then Size = 0,
      "generated measure accepted an out-of-schema value");

   Generated.Contract.Encode (Source, Short, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Destination_Too_Small and then Written = 0 and then Short = Short_Before,
      "generated short encode modified its destination");
   Generated.Contract.Encode (Source, Generated_Output, Written, Encode_Result);
   Handwritten.Contract.Encode (Source, Hand_Output, Hand_Written, Hand_Result);
   Assert
     (Encode_Result = Codecs.Encoded
      and then Hand_Result = Codecs.Encoded
      and then Written = Hand_Written
      and then Generated_Output (20 .. 26) = Expected
      and then Generated_Output (20 .. 26) = Hand_Output (20 .. 26)
      and then Generated_Output (27 .. 29) = [27 => 16#A5#, 28 => 16#A5#, 29 => 16#A5#],
      "generated and handwritten canonical bytes differ");

   Generated.Contract.Decode (Generated.Local_Schema, Expected, Decoded, Decode_Result);
   Assert (Decode_Result = Codecs.Decoded and then Decoded = Source, "generated codec did not round trip");
   Generated.Contract.Decode (Handwritten.Older_Schema, Missing_Field, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = (Code => 1, Enabled => False),
      "generated codec did not construct the approved older-writer field");
   Generated.Contract.Decode (Handwritten.Older_Schema, Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "generated codec accepted a field absent from the older writer schema");
   Generated.Contract.Decode (Handwritten.Future_Schema, Unknown_Field, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = (Code => 1, Enabled => True),
      "generated codec did not ignore the approved future-writer field");
   Generated.Contract.Decode (Handwritten.Future_Schema, Oversized_Future, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = (Code => 1, Enabled => False),
      "generated codec accepted an ignored field outside its writer-schema bound");
   Generated.Contract.Decode (Generated.Local_Schema, Missing_Field, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = (Code => 1, Enabled => False),
      "generated codec accepted a missing field or partially published");
   Generated.Contract.Decode (Generated.Local_Schema, Invalid_Boolean, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "generated codec accepted an invalid Boolean or partially published");
   Generated.Contract.Decode (Generated.Local_Schema, Unknown_Field, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "generated exact codec accepted an unknown field or partially published");
end Generated_Codec_Smoke;
