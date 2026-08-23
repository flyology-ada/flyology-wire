with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Flyology_Wire.Profiles;
with Profile_1_Test_Types;

package Profile_1_Test_Codec is
   subtype Value is Profile_1_Test_Types.Value;

   Local_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      => [0 => 16#51#, others => 0],
      Fingerprint =>
        Flyology_Wire.Identities.Fingerprint_From_Bytes
          ([16#33#,
            16#3F#,
            16#54#,
            16#15#,
            16#5F#,
            16#BA#,
            16#83#,
            16#44#,
            16#27#,
            16#8B#,
            16#98#,
            16#98#,
            16#3B#,
            16#8C#,
            16#E9#,
            16#1E#,
            16#AE#,
            16#C6#,
            16#07#,
            16#4E#,
            16#3E#,
            16#BD#,
            16#F3#,
            16#E2#,
            16#23#,
            16#F7#,
            16#F5#,
            16#20#,
            16#D1#,
            16#53#,
            16#2C#,
            16#26#]),
      Revision    => 2,
      Profile     => Flyology_Wire.Profiles.Canonical_Tagged);

   Older_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      => Local_Schema.Family,
      Fingerprint =>
        Flyology_Wire.Identities.Fingerprint_From_Bytes
          ([16#AF#,
            16#88#,
            16#11#,
            16#DC#,
            16#A0#,
            16#04#,
            16#CA#,
            16#93#,
            16#2F#,
            16#D6#,
            16#55#,
            16#4B#,
            16#1A#,
            16#A5#,
            16#BF#,
            16#C2#,
            16#1D#,
            16#AC#,
            16#98#,
            16#67#,
            16#68#,
            16#74#,
            16#57#,
            16#CE#,
            16#23#,
            16#67#,
            16#8D#,
            16#CF#,
            16#A9#,
            16#A8#,
            16#F3#,
            16#B5#]),
      Revision    => 1,
      Profile     => Local_Schema.Profile);

   Future_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      => Local_Schema.Family,
      Fingerprint =>
        Flyology_Wire.Identities.Fingerprint_From_Bytes
          ([16#00#,
            16#81#,
            16#B2#,
            16#DA#,
            16#ED#,
            16#D5#,
            16#F3#,
            16#6A#,
            16#30#,
            16#B6#,
            16#53#,
            16#62#,
            16#DA#,
            16#E4#,
            16#80#,
            16#12#,
            16#F5#,
            16#D0#,
            16#E8#,
            16#03#,
            16#80#,
            16#0A#,
            16#DB#,
            16#D8#,
            16#F2#,
            16#33#,
            16#09#,
            16#8D#,
            16#17#,
            16#DC#,
            16#B0#,
            16#71#]),
      Revision    => 3,
      Profile     => Local_Schema.Profile);

   Value_Descriptor : constant Flyology_Wire.Codecs.Codec_Descriptor :=
     (Schema => Local_Schema, Maximum_Encoded_Size => Flyology_Wire.Codecs.Bounded (15));

   procedure Measure
     (Item : Value; Size : out Flyology_Wire.Byte_Count; Status : out Flyology_Wire.Codecs.Measure_Status);

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
end Profile_1_Test_Codec;
