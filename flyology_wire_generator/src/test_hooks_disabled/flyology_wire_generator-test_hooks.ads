--  SPDX-License-Identifier: MIT OR Apache-2.0

private package Flyology_Wire_Generator.Test_Hooks is
   Enabled : constant Boolean := False;

   procedure Arm_Parser_Release_Failure
   with
     Import,
     Convention    => Ada,
     External_Name => "flyology_wire_generator_disabled_arm_parser_release_failure";

   function Consume_Parser_Release_Failure return Boolean
   with
     Import,
     Convention    => Ada,
     External_Name => "flyology_wire_generator_disabled_consume_parser_release_failure";
end Flyology_Wire_Generator.Test_Hooks;
