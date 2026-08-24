--  SPDX-License-Identifier: MIT OR Apache-2.0

private package Flyology_Wire_Generator.Test_Hooks is
   Enabled : constant Boolean := True;

   procedure Arm_Parser_Release_Failure;
   function Consume_Parser_Release_Failure return Boolean;
end Flyology_Wire_Generator.Test_Hooks;
