with Flyology_Wire.Compatibility;
with Flyology_Wire.Identities;

procedure Compatibility_Smoke is
   package Compatibility renames Flyology_Wire.Compatibility;
   package IDs renames Flyology_Wire.Identities;

   use type Compatibility.Schema_Relationship;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Local : constant IDs.Schema_Identity :=
     (Family      => [0 => 1, others => 0],
      Fingerprint => [0 => 16#A1#, others => 0],
      Revision    => 2,
      Profile     => 1);

   Older : constant IDs.Schema_Identity :=
     (Family      => Local.Family,
      Fingerprint => [0 => 16#A0#, others => 0],
      Revision    => 1,
      Profile     => Local.Profile);

   Newer : constant IDs.Schema_Identity :=
     (Family      => Local.Family,
      Fingerprint => [0 => 16#A2#, others => 0],
      Revision    => 3,
      Profile     => Local.Profile);

   Other_Family : constant IDs.Schema_Identity :=
     (Family      => [0 => 2, others => 0],
      Fingerprint => [0 => 16#B1#, others => 0],
      Revision    => 1,
      Profile     => Local.Profile);

   Other_Profile : constant IDs.Schema_Identity :=
     (Family => Local.Family, Fingerprint => [0 => 16#C1#, others => 0], Revision => 1, Profile => 2);

   Invalid : constant IDs.Schema_Identity :=
     (Family => [others => 0], Fingerprint => [others => 0], Revision => 1, Profile => 1);

   Accepted   : constant Compatibility.Schema_Identity_Array := [1 => Older, 2 => Newer];
   Zero_Based : constant Compatibility.Schema_Identity_Array := [0 => Older, 1 => Newer];
   Empty      : constant Compatibility.Schema_Identity_Array (1 .. 0) := [others => Local];
begin
   Assert (Compatibility.Is_Valid (Local, Accepted), "valid accepted-writer table was rejected");
   Assert (Compatibility.Is_Valid (Local, Zero_Based), "zero-based accepted-writer table was rejected");
   Assert (Compatibility.Is_Valid (Local, Empty), "empty accepted-writer table was rejected");
   Assert
     (not Compatibility.Is_Valid (Local, [1 => Older, 2 => Older]), "duplicate accepted writer was allowed");
   Assert
     (not Compatibility.Is_Valid (Local, [1 => Local]), "local identity was allowed in compatible writers");
   Assert (not Compatibility.Is_Valid (Local, [1 => Other_Family]), "cross-family compatibility was allowed");
   Assert
     (not Compatibility.Is_Valid (Local, [1 => Other_Profile]), "cross-profile compatibility was allowed");
   Assert (not Compatibility.Is_Valid (Local, [1 => Invalid]), "invalid compatible writer was allowed");
   Assert (not Compatibility.Is_Valid (Invalid, Empty), "invalid local identity was accepted");

   Assert
     (Compatibility.Classify (Local, Local, Accepted) = Compatibility.Exact,
      "exact writer was not classified exactly");
   Assert
     (Compatibility.Classify (Local, Older, Accepted) = Compatibility.Compatible
      and then Compatibility.Classify (Local, Newer, Accepted) = Compatibility.Compatible,
      "accepted writer was not classified directionally compatible");
   Assert
     (Compatibility.Classify (Local, Other_Family, Accepted) = Compatibility.Rejected
      and then Compatibility.Classify (Local, Other_Profile, Accepted) = Compatibility.Rejected,
      "foreign family or profile was accepted");
   Assert
     (Compatibility.Classify (Local, Invalid, Accepted) = Compatibility.Invalid_Schema
      and then Compatibility.Classify (Invalid, Local, Empty) = Compatibility.Invalid_Schema,
      "invalid schema was not distinguished from rejection");
   Assert
     (Compatibility.Classify (Local, Older, [1 => Older, 2 => Older]) = Compatibility.Invalid_Table,
      "invalid table did not fail closed during classification");
   Assert
     (Compatibility.Classify (Local, Older, Empty) = Compatibility.Rejected,
      "unlisted same-family writer was accepted");
   Assert
     (Compatibility.Classify (Older, Local, Empty) = Compatibility.Rejected,
      "compatibility was inferred in the reverse direction");
end Compatibility_Smoke;
