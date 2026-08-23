with Flyology_Wire.Identities;

--  Directional reader/writer schema selection shared by generated and
--  handwritten codecs. Compatibility proof and unknown-tag policy remain in
--  the offline schema generator and generated codec.

package Flyology_Wire.Compatibility
  with Pure
is
   subtype Schema_Identity is Identities.Schema_Identity;

   type Schema_Identity_Array is array (Natural range <>) of Schema_Identity;

   type Schema_Relationship is (Invalid_Schema, Invalid_Table, Exact, Compatible, Rejected);

   --  Validate a directional accepted-writer table for Local. Compatible
   --  writers must be valid, unique, nonlocal, and in the same family/profile.
   function Is_Valid (Local : Schema_Identity; Compatible_Writers : Schema_Identity_Array) return Boolean;

   --  Classify Writer for Local. Invalid identities and tables are
   --  distinguished from a valid but unsupported schema. Accepted entries are
   --  compared exactly.
   function Classify
     (Local : Schema_Identity; Writer : Schema_Identity; Compatible_Writers : Schema_Identity_Array)
      return Schema_Relationship;
end Flyology_Wire.Compatibility;
