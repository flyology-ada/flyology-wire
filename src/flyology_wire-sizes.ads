--  Overflow-safe arithmetic for exact wire-size measurement. Failed
--  operations publish zero, except Accumulate, which leaves Total unchanged.

package Flyology_Wire.Sizes
  with Pure
is
   type Arithmetic_Status is (Computed, Overflow);

   procedure Add
     (Left : Byte_Count; Right : Byte_Count; Result : out Byte_Count; Status : out Arithmetic_Status);

   procedure Multiply
     (Left : Byte_Count; Right : Byte_Count; Result : out Byte_Count; Status : out Arithmetic_Status);

   procedure Accumulate (Total : in out Byte_Count; Amount : Byte_Count; Status : out Arithmetic_Status);
end Flyology_Wire.Sizes;
