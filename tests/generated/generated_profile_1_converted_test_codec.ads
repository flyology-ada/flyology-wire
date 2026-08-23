with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Flyology_Wire.Profiles;
with Wire_Shape;

package Generated_Profile_1_Converted_Test_Codec is
   subtype Value is Wire_Shape.Public_Record;

   Local_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      =>
        Flyology_Wire.Identities.Family_From_Bytes
          ([16#58#,
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
          ([16#E2#,
            16#2A#,
            16#7C#,
            16#3C#,
            16#FF#,
            16#FE#,
            16#46#,
            16#0E#,
            16#9D#,
            16#1B#,
            16#8C#,
            16#82#,
            16#88#,
            16#BF#,
            16#27#,
            16#94#,
            16#E7#,
            16#9A#,
            16#3F#,
            16#9F#,
            16#F5#,
            16#2D#,
            16#C3#,
            16#D6#,
            16#55#,
            16#8B#,
            16#AF#,
            16#CA#,
            16#E1#,
            16#DC#,
            16#6C#,
            16#C1#]),
      Revision    => 1,
      Profile     => Flyology_Wire.Profiles.Canonical_Tagged);

   Value_Descriptor : constant Flyology_Wire.Codecs.Codec_Descriptor :=
     (Schema => Local_Schema,
      Maximum_Encoded_Size =>
        Flyology_Wire.Codecs.Bounded (13));

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
end Generated_Profile_1_Converted_Test_Codec;
