package body Wire_Test_Codec is
   use type Interfaces.Unsigned_64;
   use type Flyology_Wire.Codecs.Schema_Identity;
   use type Flyology_Wire.Octet;
   use type Flyology_Wire.Octet_Offset;

   Encoded_Length : constant Flyology_Wire.Octet_Count := 9;

   procedure Measure
     (Item : Value; Size : out Flyology_Wire.Byte_Count; Status : out Flyology_Wire.Codecs.Measure_Status) is
   begin
      Size := 0;
      if Item.Code = 0 then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Size := Flyology_Wire.Byte_Count (Encoded_Length);
         Status := Flyology_Wire.Codecs.Measured;
      end if;
   end Measure;

   procedure Encode
     (Item    : Value;
      Output  : in out Flyology_Wire.Octet_Array;
      Written : out Flyology_Wire.Octet_Count;
      Status  : out Flyology_Wire.Codecs.Encode_Status)
   is
      Size           : Flyology_Wire.Byte_Count;
      Measure_Result : Flyology_Wire.Codecs.Measure_Status;
   begin
      Written := 0;
      Measure (Item, Size, Measure_Result);
      case Measure_Result is
         when Flyology_Wire.Codecs.Invalid_Value =>
            Status := Flyology_Wire.Codecs.Invalid_Value;
            return;

         when Flyology_Wire.Codecs.Size_Overflow =>
            Status := Flyology_Wire.Codecs.Size_Overflow;
            return;

         when Flyology_Wire.Codecs.Measured      =>
            null;
      end case;

      if Output'Length < Encoded_Length then
         Status := Flyology_Wire.Codecs.Destination_Too_Small;
         return;
      end if;

      for Step in 0 .. 7 loop
         Output (Output'First + Flyology_Wire.Octet_Offset (Step)) :=
           Flyology_Wire.Octet (Interfaces.Shift_Right (Item.Code, (7 - Step) * 8) and 16#FF#);
      end loop;
      Output (Output'First + 8) := Flyology_Wire.Octet (Boolean'Pos (Item.Enabled));
      Written := Encoded_Length;
      Status := Flyology_Wire.Codecs.Encoded;
   end Encode;

   procedure Decode
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Item   : out Value;
      Status : out Flyology_Wire.Codecs.Decode_Status)
   is
      Candidate : Value := (Code => 0, Enabled => False);
   begin
      Item := (Code => 1, Enabled => False);
      if not Flyology_Wire.Codecs.Is_Valid (Writer) or else Writer /= Value_Descriptor.Schema then
         Status := Flyology_Wire.Codecs.Incompatible;
         return;
      elsif Input'Length /= Encoded_Length then
         Status := Flyology_Wire.Codecs.Malformed;
         return;
      end if;

      for Step in 0 .. 7 loop
         Candidate.Code :=
           Interfaces.Shift_Left (Candidate.Code, 8)
           or Interfaces.Unsigned_64 (Input (Input'First + Flyology_Wire.Octet_Offset (Step)));
      end loop;
      if Candidate.Code = 0 then
         Status := Flyology_Wire.Codecs.Invalid_Value;
         return;
      elsif Input (Input'First + 8) > 1 then
         Status := Flyology_Wire.Codecs.Noncanonical;
         return;
      end if;

      Candidate.Enabled := Input (Input'First + 8) = 1;
      Item := Candidate;
      Status := Flyology_Wire.Codecs.Decoded;
   end Decode;
end Wire_Test_Codec;
