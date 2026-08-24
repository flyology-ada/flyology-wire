--  SPDX-License-Identifier: MIT OR Apache-2.0

with Ada.Streams;
with Ada.Text_IO;
with Flyology_Wire_Generator.Hashing;

procedure Hashing_Tests is
   use Flyology_Wire_Generator.Hashing;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Check;

   Empty_Bytes : Ada.Streams.Stream_Element_Array (4 .. 3);
   ABC_Bytes   : constant Ada.Streams.Stream_Element_Array :=
     [7 => Character'Pos ('a'), 8 => Character'Pos ('b'), 9 => Character'Pos ('c')];
begin
   Check
     (SHA_256 ("") = "e3b0c44298fc1c149afbf4c8996fb924" & "27ae41e4649b934ca495991b7852b855",
      "wrong SHA-256 for the empty string");
   Check
     (SHA_256 ("abc") = "ba7816bf8f01cfea414140de5dae2223" & "b00361a396177a9cb410ff61f20015ad",
      "wrong SHA-256 for abc");
   Check
     (SHA_256 (Empty_Bytes) = SHA_256 (""), "stream hash mishandles an empty arbitrary-lower-bound array");
   Check (SHA_256 (ABC_Bytes) = SHA_256 ("abc"), "stream and string hashes differ");
   Ada.Text_IO.Put_Line ("hashing tests passed");
end Hashing_Tests;
