with Interfaces;

--  Stable wire-schema identities and their canonical byte encodings. These
--  values identify payload contracts; they provide neither authentication nor
--  integrity protection.

package Flyology_Wire.Identities
  with Pure
is
   Family_ID_Length          : constant Octet_Count := 16;
   Schema_Fingerprint_Length : constant Octet_Count := 32;
   Scalar_ID_Length          : constant Octet_Count := 4;
   Schema_Identity_Length    : constant Octet_Count := 56;

   type Family_ID is array (Octet_Offset range 0 .. 15) of Octet;
   type Schema_Fingerprint is array (Octet_Offset range 0 .. 31) of Octet;

   type Schema_Revision is new Interfaces.Unsigned_32 range 1 .. Interfaces.Unsigned_32'Last;
   type Profile_ID is new Interfaces.Unsigned_32 range 1 .. Interfaces.Unsigned_32'Last;

   --  Complete semantic and encoding identity carried with one payload. This
   --  value has no stable in-memory representation.
   type Schema_Identity is record
      Family      : Family_ID;
      Fingerprint : Schema_Fingerprint;
      Revision    : Schema_Revision;
      Profile     : Profile_ID;
   end record;

   type Family_ID_Bytes is array (Octet_Offset range 0 .. 15) of Octet;
   type Schema_Fingerprint_Bytes is array (Octet_Offset range 0 .. 31) of Octet;
   type Scalar_ID_Bytes is array (Octet_Offset range 0 .. 3) of Octet;
   type Schema_Identity_Bytes is array (Octet_Offset range 0 .. 55) of Octet;

   --  A zero family identifier is reserved as an invalid sentinel.
   function Is_Valid (Item : Family_ID) return Boolean;

   --  A zero schema fingerprint is reserved as an invalid sentinel.
   function Is_Valid (Item : Schema_Fingerprint) return Boolean;

   --  A schema identity is valid when its family and fingerprint are nonzero.
   --  Its revision and profile types exclude zero by construction.
   function Is_Valid (Item : Schema_Identity) return Boolean;

   --  Return canonical opaque family bytes in index order.
   function To_Bytes (Item : Family_ID) return Family_ID_Bytes;
   --  Construct an opaque family identifier from canonical bytes.
   function Family_From_Bytes (Item : Family_ID_Bytes) return Family_ID;

   --  Return canonical fingerprint bytes in index order.
   function To_Bytes (Item : Schema_Fingerprint) return Schema_Fingerprint_Bytes;
   --  Construct a fingerprint from canonical bytes.
   function Fingerprint_From_Bytes (Item : Schema_Fingerprint_Bytes) return Schema_Fingerprint;

   --  Return a canonical unsigned big-endian schema revision.
   function To_Bytes (Item : Schema_Revision) return Scalar_ID_Bytes;
   --  Return a canonical unsigned big-endian profile identifier.
   function To_Bytes (Item : Profile_ID) return Scalar_ID_Bytes;

   --  Fail-closed scalar identity decode result.
   type Scalar_Decode_Status is (Decoded, Zero_Is_Invalid);

   --  Decode a canonical unsigned big-endian nonzero schema revision. Item is
   --  initialized to one on failure.
   procedure Revision_From_Bytes
     (Input : Scalar_ID_Bytes; Item : out Schema_Revision; Status : out Scalar_Decode_Status);

   --  Decode a canonical unsigned big-endian nonzero profile identifier. Item
   --  is initialized to one on failure.
   procedure Profile_From_Bytes
     (Input : Scalar_ID_Bytes; Item : out Profile_ID; Status : out Scalar_Decode_Status);

   --  Canonical identity order is family, fingerprint, unsigned big-endian
   --  revision, then unsigned big-endian profile.
   function To_Bytes (Item : Schema_Identity) return Schema_Identity_Bytes;

   type Schema_Identity_Decode_Status is
     (Identity_Decoded, Invalid_Family, Invalid_Fingerprint, Invalid_Revision, Invalid_Profile);

   --  Decode and validate a complete canonical schema identity. Failure
   --  publishes the invalid zero-family/zero-fingerprint sentinel with scalar
   --  fields initialized to one.
   procedure Schema_Identity_From_Bytes
     (Input : Schema_Identity_Bytes; Item : out Schema_Identity; Status : out Schema_Identity_Decode_Status);
end Flyology_Wire.Identities;
