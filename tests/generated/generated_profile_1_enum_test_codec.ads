with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Flyology_Wire.Profiles;
with Profile_1_Enumeration_Test_Types;

package Generated_Profile_1_Enum_Test_Codec is
   subtype Value is Profile_1_Enumeration_Test_Types.Value;

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
          ([16#06#,
            16#41#,
            16#28#,
            16#1E#,
            16#8A#,
            16#46#,
            16#09#,
            16#EE#,
            16#E8#,
            16#E9#,
            16#4B#,
            16#22#,
            16#A5#,
            16#A0#,
            16#65#,
            16#74#,
            16#B9#,
            16#75#,
            16#17#,
            16#2F#,
            16#58#,
            16#59#,
            16#2F#,
            16#17#,
            16#32#,
            16#E0#,
            16#A5#,
            16#70#,
            16#8E#,
            16#66#,
            16#2F#,
            16#EA#]),
      Revision    => 1,
      Profile     => Flyology_Wire.Profiles.Canonical_Tagged);

   Value_Descriptor : constant Flyology_Wire.Codecs.Codec_Descriptor :=
     (Schema => Local_Schema,
      Maximum_Encoded_Size =>
        Flyology_Wire.Codecs.Bounded (3));

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
end Generated_Profile_1_Enum_Test_Codec;
