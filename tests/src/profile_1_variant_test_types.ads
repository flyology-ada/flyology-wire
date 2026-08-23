with Interfaces;

package Profile_1_Variant_Test_Types is
   type Choice_Kind is (Number_Choice, Flag_Choice);
   for Choice_Kind use (Number_Choice => 41, Flag_Choice => 73);

   type Value is record
      Kind   : Choice_Kind := Number_Choice;
      Number : Interfaces.Unsigned_64 := 0;
      Flag   : Boolean := False;
   end record;
end Profile_1_Variant_Test_Types;
