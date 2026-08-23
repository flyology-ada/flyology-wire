with Flyology_Wire.Codecs;
with Flyology_Wire.Profiles;
with Interfaces;

package Profile_1_Test_Observer is
   Observer_Schema : constant Flyology_Wire.Codecs.Schema_Identity :=
     (Family      => [0 => 16#52#, others => 0],
      Fingerprint => [0 => 16#B2#, others => 0],
      Revision    => 1,
      Profile     => Flyology_Wire.Profiles.Canonical_Tagged);

   generic
      with procedure Visit_Code (Value : Interfaces.Unsigned_64);
      with procedure Visit_Data (Value : Flyology_Wire.Octet_Array);
   procedure Validate_And_Visit
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Status : out Flyology_Wire.Codecs.Decode_Status);
end Profile_1_Test_Observer;
