with Flyology_Wire;
with Interfaces;

package Profile_1_Text_Test_Types is
   subtype UTF_8_Array is Flyology_Wire.Octet_Array (1 .. 8);

   type Value is record
      UTF_8        : UTF_8_Array;
      UTF_8_Length : Interfaces.Unsigned_64;
   end record;
end Profile_1_Text_Test_Types;
