with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Profiles;
with Interfaces;

package Profile_1_Test_Codec is
   type Value is record
      Code    : Interfaces.Unsigned_64;
      Enabled : Boolean;
   end record;

   Local_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      => [0 => 16#51#, others => 0],
      Fingerprint => [0 => 16#A2#, others => 0],
      Revision    => 2,
      Profile     => Flyology_Wire.Profiles.Canonical_Tagged);

   Older_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      => Local_Schema.Family,
      Fingerprint => [0 => 16#A1#, others => 0],
      Revision    => 1,
      Profile     => Local_Schema.Profile);

   Future_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      => Local_Schema.Family,
      Fingerprint => [0 => 16#A3#, others => 0],
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
