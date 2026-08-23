with Interfaces;

package Profile_1_Sequence_Test_Types is
   type Item_Array is array (Positive range 1 .. 4) of Interfaces.Unsigned_64;

   type Value is record
      Items  : Item_Array;
      Length : Interfaces.Unsigned_64;
   end record;
end Profile_1_Sequence_Test_Types;
