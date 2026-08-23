with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Flyology_Wire.Profiles;
with Profile_1_Text_Test_Types;

package Generated_Profile_1_Text_Test_Codec is
   subtype Value is Profile_1_Text_Test_Types.Value;

   Local_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      =>
        Flyology_Wire.Identities.Family_From_Bytes
          ([16#56#,
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
          ([16#0C#,
            16#21#,
            16#27#,
            16#7C#,
            16#E7#,
            16#BF#,
            16#A4#,
            16#AF#,
            16#4C#,
            16#AE#,
            16#2E#,
            16#BD#,
            16#F8#,
            16#DE#,
            16#11#,
            16#16#,
            16#9E#,
            16#ED#,
            16#E9#,
            16#70#,
            16#A1#,
            16#0F#,
            16#60#,
            16#BA#,
            16#6F#,
            16#C3#,
            16#C0#,
            16#BD#,
            16#5A#,
            16#4C#,
            16#B3#,
            16#6A#]),
      Revision    => 1,
      Profile     => Flyology_Wire.Profiles.Canonical_Tagged);

   Value_Descriptor : constant Flyology_Wire.Codecs.Codec_Descriptor :=
     (Schema => Local_Schema,
      Maximum_Encoded_Size =>
        Flyology_Wire.Codecs.Bounded (10));

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

   generic
      with procedure Visit_UTF_8 (Value : Flyology_Wire.Octet_Array);
   procedure Validate_And_Visit
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Status : out Flyology_Wire.Codecs.Decode_Status);

   package Contract is new
     Flyology_Wire.Codecs.Contracts
       (Value_Type       => Value,
        Value_Descriptor => Value_Descriptor,
        Measure_Value    => Measure,
        Encode_Value     => Encode,
        Decode_Value     => Decode);
end Generated_Profile_1_Text_Test_Codec;
