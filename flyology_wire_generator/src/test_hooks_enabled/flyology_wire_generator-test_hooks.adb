--  SPDX-License-Identifier: MIT OR Apache-2.0

package body Flyology_Wire_Generator.Test_Hooks is
   Parser_Release_Failure_Armed : Boolean := False;

   procedure Arm_Parser_Release_Failure is
   begin
      Parser_Release_Failure_Armed := True;
   end Arm_Parser_Release_Failure;

   function Consume_Parser_Release_Failure return Boolean is
      Result : constant Boolean := Parser_Release_Failure_Armed;
   begin
      Parser_Release_Failure_Armed := False;
      return Result;
   end Consume_Parser_Release_Failure;
end Flyology_Wire_Generator.Test_Hooks;
