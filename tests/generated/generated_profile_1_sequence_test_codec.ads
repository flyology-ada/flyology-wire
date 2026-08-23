with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Flyology_Wire.Profiles;
with Profile_1_Sequence_Test_Types;

package Generated_Profile_1_Sequence_Test_Codec is
   subtype Value is Profile_1_Sequence_Test_Types.Value;

   Local_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      =>
        Flyology_Wire.Identities.Family_From_Bytes
          ([16#54#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#,
            16#00#]),
      Fingerprint =>
        Flyology_Wire.Identities.Fingerprint_From_Bytes
          ([16#54#,
            16#0D#,
            16#12#,
            16#0E#,
            16#71#,
            16#DC#,
            16#57#,
            16#B2#,
            16#0E#,
            16#42#,
            16#A5#,
            16#AF#,
            16#BB#,
            16#B4#,
            16#F8#,
            16#80#,
            16#2D#,
            16#3F#,
            16#75#,
            16#F5#,
            16#A4#,
            16#49#,
            16#DB#,
            16#5C#,
            16#F0#,
            16#A5#,
            16#7C#,
            16#9B#,
            16#B2#,
            16#1D#,
            16#B4#,
            16#13#]),
      Revision    => 1,
      Profile     => Flyology_Wire.Profiles.Canonical_Tagged);

   Value_Descriptor : constant Flyology_Wire.Codecs.Codec_Descriptor :=
     (Schema => Local_Schema,
      Maximum_Encoded_Size =>
        Flyology_Wire.Codecs.Bounded (15));

   procedure Measure
     (Item   : Value;
      Size   : out Flyology_Wire.Byte_Count;
      Status : out Flyology_Wire.Codecs.Measure_Status);

   procedure Encode
     (Item    : Value;
      Output  : in out Flyology_Wire.Octet_Array;
      Written : out Flyology_Wire.Octet_Count;
      Status  : out Flyology_Wire.Codecs.Encode_Status);

   procedure Decode
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Item   : out Value;
      Status : out Flyology_Wire.Codecs.Decode_Status);

   package Contract is new
     Flyology_Wire.Codecs.Contracts
       (Value_Type       => Value,
        Value_Descriptor => Value_Descriptor,
        Measure_Value    => Measure,
        Encode_Value     => Encode,
        Decode_Value     => Decode);
end Generated_Profile_1_Sequence_Test_Codec;
