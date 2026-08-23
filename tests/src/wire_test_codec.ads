with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Interfaces;

package Wire_Test_Codec is
   type Value is record
      Code    : Interfaces.Unsigned_64;
      Enabled : Boolean;
   end record;

   Value_Descriptor : constant Flyology_Wire.Codecs.Codec_Descriptor :=
     (Schema               =>
        (Family      => [0 => 1, others => 0],
         Fingerprint => [0 => 16#A5#, others => 0],
         Revision    => 1,
         --  Reserved for this internal smoke codec; it is not a production
         --  canonical payload profile.
         Profile     => Flyology_Wire.Identities.Profile_ID'Last),
      Maximum_Encoded_Size => Flyology_Wire.Codecs.Bounded (9));

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
end Wire_Test_Codec;
