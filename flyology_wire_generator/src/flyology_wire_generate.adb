--  SPDX-License-Identifier: MIT OR Apache-2.0

with Ada.Command_Line;
with Ada.Text_IO;
with Flyology_Wire_Generator_Config;

procedure Flyology_Wire_Generate is
   procedure Usage is
   begin
      Ada.Text_IO.Put_Line ("usage: flyology_wire_generate COMMAND [ARGUMENT ...]");
      Ada.Text_IO.Put_Line ("       flyology_wire_generate --version");
   end Usage;
begin
   if Ada.Command_Line.Argument_Count = 1 and then Ada.Command_Line.Argument (1) = "--version" then
      Ada.Text_IO.Put_Line
        (Flyology_Wire_Generator_Config.Crate_Name & " " & Flyology_Wire_Generator_Config.Crate_Version);
   elsif Ada.Command_Line.Argument_Count = 1
     and then (Ada.Command_Line.Argument (1) = "help" or else Ada.Command_Line.Argument (1) = "--help")
   then
      Usage;
   else
      Usage;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Flyology_Wire_Generate;
