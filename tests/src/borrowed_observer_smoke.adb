with Ada.Streams;
with Flyology_Wire.Codecs;
with Interfaces;
with Profile_1_Test_Observer;
with System;

procedure Borrowed_Observer_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Observer renames Profile_1_Test_Observer;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Interfaces.Unsigned_64;
   use type System.Address;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Calls            : Natural := 0;
   Observed_Code    : Interfaces.Unsigned_64 := 0;
   Observed_Data    : Wire.Octet_Array (1 .. 3) := [others => 0];
   Expected_Address : System.Address := System.Null_Address;
   Same_Address     : Boolean := False;

   procedure Visit_Code (Value : Interfaces.Unsigned_64) is
   begin
      Calls := Calls + 1;
      Observed_Code := Value;
   end Visit_Code;

   procedure Visit_Data (Value : Wire.Octet_Array) is
   begin
      Calls := Calls + 1;
      Observed_Data := Value;
      Same_Address := Value'Address = Expected_Address;
   end Visit_Data;

   procedure Observe is new Observer.Validate_And_Visit (Visit_Code, Visit_Data);

   Visitor_Error : exception;

   procedure Ignore_Code (Value : Interfaces.Unsigned_64) is
      pragma Unreferenced (Value);
   begin
      null;
   end Ignore_Code;

   procedure Raise_From_Data (Value : Wire.Octet_Array) is
      pragma Unreferenced (Value);
   begin
      raise Visitor_Error;
   end Raise_From_Data;

   procedure Raising_Observe is new Observer.Validate_And_Visit (Ignore_Code, Raise_From_Data);

   Empty_Length : Natural := Natural'Last;

   procedure Visit_Empty_Data (Value : Wire.Octet_Array) is
   begin
      Empty_Length := Value'Length;
   end Visit_Empty_Data;

   procedure Empty_Observe is new Observer.Validate_And_Visit (Ignore_Code, Visit_Empty_Data);

   Payload       : aliased Wire.Octet_Array (20 .. 27) := [1, 1, 7, 2, 3, 16#AA#, 16#BB#, 16#CC#];
   Empty_Data    : constant Wire.Octet_Array := [1, 1, 7, 2, 0];
   Invalid       : constant Wire.Octet_Array := [1, 1, 7, 3, 0];
   Over_Limit    : constant Wire.Octet_Array := [1, 1, 7, 2, 5, 1, 2, 3, 4, 5];
   Decode_Result : Codecs.Decode_Status;
   Wrong_Writer  : Codecs.Schema_Identity := Observer.Observer_Schema;
   Raised        : Boolean := False;
begin
   Expected_Address := Payload (25)'Address;
   Observe (Observer.Observer_Schema, Payload, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded
      and then Calls = 2
      and then Observed_Code = 7
      and then Observed_Data = [16#AA#, 16#BB#, 16#CC#],
      "validated borrowed observation returned the wrong logical value");
   Assert (Same_Address, "borrowed data callback did not receive the original payload storage");

   Empty_Observe (Observer.Observer_Schema, Empty_Data, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Empty_Length = 0,
      "borrowed observation did not preserve an empty byte value");

   Observe (Observer.Observer_Schema, Invalid, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Calls = 2,
      "invalid payload invoked an application callback");

   Observe (Observer.Observer_Schema, Over_Limit, Decode_Result);
   Assert
     (Decode_Result = Codecs.Limit_Exceeded and then Calls = 2,
      "over-limit payload invoked an application callback");

   Wrong_Writer.Fingerprint := [0 => 16#EE#, others => 0];
   Observe (Wrong_Writer, Payload, Decode_Result);
   Assert
     (Decode_Result = Codecs.Incompatible and then Calls = 2,
      "incompatible writer invoked an application callback");

   begin
      Raising_Observe (Observer.Observer_Schema, Payload, Decode_Result);
   exception
      when Visitor_Error =>
         Raised := True;
   end;
   Assert (Raised, "application visitor exception was converted into a decode status");
end Borrowed_Observer_Smoke;
