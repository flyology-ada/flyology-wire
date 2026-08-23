with Flyology_Wire.Identities;

--  Registry of canonical payload profile identifiers owned by this crate.

package Flyology_Wire.Profiles
  with Pure
is
   subtype Profile_ID is Identities.Profile_ID;

   --  Canonical tagged payload grammar defined by decision 0003.
   Canonical_Tagged : constant Profile_ID := 1;
end Flyology_Wire.Profiles;
