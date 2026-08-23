package body Flyology_Wire.Compatibility is
   use type Identities.Family_ID;
   use type Identities.Profile_ID;
   use type Identities.Schema_Identity;

   function Is_Valid (Local : Schema_Identity; Compatible_Writers : Schema_Identity_Array) return Boolean is
   begin
      if not Identities.Is_Valid (Local) then
         return False;
      end if;

      for Index in Compatible_Writers'Range loop
         if not Identities.Is_Valid (Compatible_Writers (Index))
           or else Compatible_Writers (Index) = Local
           or else Compatible_Writers (Index).Family /= Local.Family
           or else Compatible_Writers (Index).Profile /= Local.Profile
         then
            return False;
         end if;

         if Index /= Compatible_Writers'First then
            for Earlier in Compatible_Writers'First .. Index - 1 loop
               if Compatible_Writers (Earlier) = Compatible_Writers (Index) then
                  return False;
               end if;
            end loop;
         end if;
      end loop;
      return True;
   end Is_Valid;

   function Classify
     (Local : Schema_Identity; Writer : Schema_Identity; Compatible_Writers : Schema_Identity_Array)
      return Schema_Relationship is
   begin
      if not Identities.Is_Valid (Local) or else not Identities.Is_Valid (Writer) then
         return Invalid_Schema;
      elsif not Is_Valid (Local, Compatible_Writers) then
         return Invalid_Table;
      elsif Writer = Local then
         return Exact;
      elsif Writer.Family /= Local.Family or else Writer.Profile /= Local.Profile then
         return Rejected;
      end if;

      for Candidate of Compatible_Writers loop
         if Writer = Candidate then
            return Compatible;
         end if;
      end loop;
      return Rejected;
   end Classify;
end Flyology_Wire.Compatibility;
