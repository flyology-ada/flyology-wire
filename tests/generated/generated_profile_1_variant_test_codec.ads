with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Flyology_Wire.Profiles;
with Profile_1_Variant_Test_Types;

package Generated_Profile_1_Variant_Test_Codec is
   subtype Value is Profile_1_Variant_Test_Types.Value;

   Local_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      =>
        Flyology_Wire.Identities.Family_From_Bytes
          ([16#57#,
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
          ([16#48#,
            16#32#,
            16#CE#,
            16#C5#,
            16#EA#,
            16#0D#,
            16#C2#,
            16#F8#,
            16#0D#,
            16#0E#,
            16#3A#,
            16#0F#,
            16#BC#,
            16#1B#,
            16#83#,
            16#BA#,
            16#28#,
            16#4A#,
            16#AF#,
            16#E1#,
            16#F3#,
            16#AA#,
            16#B6#,
            16#D5#,
            16#9D#,
            16#EF#,
            16#6B#,
            16#FF#,
            16#B9#,
            16#99#,
            16#60#,
            16#73#]),
      Revision    => 1,
      Profile     => Flyology_Wire.Profiles.Canonical_Tagged);

   Value_Descriptor : constant Flyology_Wire.Codecs.Codec_Descriptor :=
     (Schema => Local_Schema,
      Maximum_Encoded_Size =>
        Flyology_Wire.Codecs.Bounded (8));

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
end Generated_Profile_1_Variant_Test_Codec;
