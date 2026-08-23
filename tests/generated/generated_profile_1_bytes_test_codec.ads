with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Flyology_Wire.Profiles;
with Interfaces;
with Profile_1_Bytes_Test_Types;

package Generated_Profile_1_Bytes_Test_Codec is
   subtype Value is Profile_1_Bytes_Test_Types.Value;

   Local_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      =>
        Flyology_Wire.Identities.Family_From_Bytes
          ([16#55#,
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
          ([16#F8#,
            16#4E#,
            16#3A#,
            16#04#,
            16#54#,
            16#AD#,
            16#0C#,
            16#6E#,
            16#E4#,
            16#05#,
            16#5B#,
            16#A9#,
            16#C1#,
            16#6B#,
            16#F5#,
            16#37#,
            16#F8#,
            16#9D#,
            16#7C#,
            16#F0#,
            16#B3#,
            16#FC#,
            16#59#,
            16#3D#,
            16#73#,
            16#9C#,
            16#E3#,
            16#31#,
            16#69#,
            16#D9#,
            16#23#,
            16#AC#]),
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
      with procedure Visit_Code (Value : Interfaces.Unsigned_64);
      with procedure Visit_Data (Value : Flyology_Wire.Octet_Array);
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
end Generated_Profile_1_Bytes_Test_Codec;
