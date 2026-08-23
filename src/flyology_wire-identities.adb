package body Flyology_Wire.Identities is
   use type Interfaces.Unsigned_32;
   use type Octet;
   use type Octet_Offset;

   function Is_Valid (Item : Family_ID) return Boolean is
   begin
      for Value of Item loop
         if Value /= 0 then
            return True;
         end if;
      end loop;
      return False;
   end Is_Valid;

   function Is_Valid (Item : Schema_Fingerprint) return Boolean is
   begin
      for Value of Item loop
         if Value /= 0 then
            return True;
         end if;
      end loop;
      return False;
   end Is_Valid;

   function Is_Valid (Item : Schema_Identity) return Boolean
   is (Is_Valid (Item.Family) and then Is_Valid (Item.Fingerprint));

   function To_Bytes (Item : Family_ID) return Family_ID_Bytes is
      Result : Family_ID_Bytes;
   begin
      for Index in Item'Range loop
         Result (Index) := Item (Index);
      end loop;
      return Result;
   end To_Bytes;

   function Family_From_Bytes (Item : Family_ID_Bytes) return Family_ID is
      Result : Family_ID;
   begin
      for Index in Item'Range loop
         Result (Index) := Item (Index);
      end loop;
      return Result;
   end Family_From_Bytes;

   function To_Bytes (Item : Schema_Fingerprint) return Schema_Fingerprint_Bytes is
      Result : Schema_Fingerprint_Bytes;
   begin
      for Index in Item'Range loop
         Result (Index) := Item (Index);
      end loop;
      return Result;
   end To_Bytes;

   function Fingerprint_From_Bytes (Item : Schema_Fingerprint_Bytes) return Schema_Fingerprint is
      Result : Schema_Fingerprint;
   begin
      for Index in Item'Range loop
         Result (Index) := Item (Index);
      end loop;
      return Result;
   end Fingerprint_From_Bytes;

   function Encode_Scalar (Item : Interfaces.Unsigned_32) return Scalar_ID_Bytes is
   begin
      return
        [0 => Octet (Interfaces.Shift_Right (Item, 24) and 16#FF#),
         1 => Octet (Interfaces.Shift_Right (Item, 16) and 16#FF#),
         2 => Octet (Interfaces.Shift_Right (Item, 8) and 16#FF#),
         3 => Octet (Item and 16#FF#)];
   end Encode_Scalar;

   function To_Bytes (Item : Schema_Revision) return Scalar_ID_Bytes
   is (Encode_Scalar (Interfaces.Unsigned_32 (Item)));

   function To_Bytes (Item : Profile_ID) return Scalar_ID_Bytes
   is (Encode_Scalar (Interfaces.Unsigned_32 (Item)));

   function Decode_Scalar (Input : Scalar_ID_Bytes) return Interfaces.Unsigned_32 is
      Result : Interfaces.Unsigned_32 := 0;
   begin
      for Value of Input loop
         Result := Interfaces.Shift_Left (Result, 8) or Interfaces.Unsigned_32 (Value);
      end loop;
      return Result;
   end Decode_Scalar;

   procedure Revision_From_Bytes
     (Input : Scalar_ID_Bytes; Item : out Schema_Revision; Status : out Scalar_Decode_Status)
   is
      Value : constant Interfaces.Unsigned_32 := Decode_Scalar (Input);
   begin
      Item := Schema_Revision'First;
      if Value = 0 then
         Status := Zero_Is_Invalid;
      else
         Item := Schema_Revision (Value);
         Status := Decoded;
      end if;
   end Revision_From_Bytes;

   procedure Profile_From_Bytes
     (Input : Scalar_ID_Bytes; Item : out Profile_ID; Status : out Scalar_Decode_Status)
   is
      Value : constant Interfaces.Unsigned_32 := Decode_Scalar (Input);
   begin
      Item := Profile_ID'First;
      if Value = 0 then
         Status := Zero_Is_Invalid;
      else
         Item := Profile_ID (Value);
         Status := Decoded;
      end if;
   end Profile_From_Bytes;

   function To_Bytes (Item : Schema_Identity) return Schema_Identity_Bytes is
      Result         : Schema_Identity_Bytes := [others => 0];
      Revision_Bytes : constant Scalar_ID_Bytes := To_Bytes (Item.Revision);
      Profile_Bytes  : constant Scalar_ID_Bytes := To_Bytes (Item.Profile);
   begin
      for Index in Item.Family'Range loop
         Result (Index) := Item.Family (Index);
      end loop;
      for Index in Item.Fingerprint'Range loop
         Result (Octet_Offset (16) + Index) := Item.Fingerprint (Index);
      end loop;
      for Index in Revision_Bytes'Range loop
         Result (Octet_Offset (48) + Index) := Revision_Bytes (Index);
         Result (Octet_Offset (52) + Index) := Profile_Bytes (Index);
      end loop;
      return Result;
   end To_Bytes;

   procedure Schema_Identity_From_Bytes
     (Input : Schema_Identity_Bytes; Item : out Schema_Identity; Status : out Schema_Identity_Decode_Status)
   is
      Candidate      : Schema_Identity :=
        (Family => [others => 0], Fingerprint => [others => 0], Revision => 1, Profile => 1);
      Revision_Bytes : Scalar_ID_Bytes;
      Profile_Bytes  : Scalar_ID_Bytes;
      Scalar_Status  : Scalar_Decode_Status;
   begin
      Item := Candidate;
      for Index in Candidate.Family'Range loop
         Candidate.Family (Index) := Input (Index);
      end loop;
      if not Is_Valid (Candidate.Family) then
         Status := Invalid_Family;
         return;
      end if;

      for Index in Candidate.Fingerprint'Range loop
         Candidate.Fingerprint (Index) := Input (Octet_Offset (16) + Index);
      end loop;
      if not Is_Valid (Candidate.Fingerprint) then
         Status := Invalid_Fingerprint;
         return;
      end if;

      for Index in Scalar_ID_Bytes'Range loop
         Revision_Bytes (Index) := Input (Octet_Offset (48) + Index);
         Profile_Bytes (Index) := Input (Octet_Offset (52) + Index);
      end loop;
      Revision_From_Bytes (Revision_Bytes, Candidate.Revision, Scalar_Status);
      if Scalar_Status /= Decoded then
         Status := Invalid_Revision;
         return;
      end if;
      Profile_From_Bytes (Profile_Bytes, Candidate.Profile, Scalar_Status);
      if Scalar_Status /= Decoded then
         Status := Invalid_Profile;
         return;
      end if;

      Item := Candidate;
      Status := Identity_Decoded;
   end Schema_Identity_From_Bytes;
end Flyology_Wire.Identities;
