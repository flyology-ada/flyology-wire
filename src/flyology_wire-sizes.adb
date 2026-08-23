package body Flyology_Wire.Sizes is
   procedure Add
     (Left : Byte_Count; Right : Byte_Count; Result : out Byte_Count; Status : out Arithmetic_Status) is
   begin
      Result := 0;
      if Right > Byte_Count'Last - Left then
         Status := Overflow;
      else
         Result := Left + Right;
         Status := Computed;
      end if;
   end Add;

   procedure Multiply
     (Left : Byte_Count; Right : Byte_Count; Result : out Byte_Count; Status : out Arithmetic_Status) is
   begin
      Result := 0;
      if Left /= 0 and then Right > Byte_Count'Last / Left then
         Status := Overflow;
      else
         Result := Left * Right;
         Status := Computed;
      end if;
   end Multiply;

   procedure Accumulate (Total : in out Byte_Count; Amount : Byte_Count; Status : out Arithmetic_Status) is
      Candidate : Byte_Count;
   begin
      Add (Total, Amount, Candidate, Status);
      if Status = Computed then
         Total := Candidate;
      end if;
   end Accumulate;
end Flyology_Wire.Sizes;
