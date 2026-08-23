with Flyology_Wire;
with Interfaces;

package Profile_1_Bytes_Test_Types is
   subtype Data_Array is Flyology_Wire.Octet_Array (3 .. 5);

   type Value is record
      Code        : Interfaces.Unsigned_64;
      Data        : Data_Array;
      Data_Length : Interfaces.Unsigned_64;
   end record;
end Profile_1_Bytes_Test_Types;
