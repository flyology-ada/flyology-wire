package Profile_1_Enumeration_Test_Types is
   type Color is (Red, Green);
   for Color use (Red => 42, Green => 99);

   type Value is record
      Shade : Color;
   end record;
end Profile_1_Enumeration_Test_Types;
