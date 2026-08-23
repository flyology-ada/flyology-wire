with Ada.Streams;
with Flyology_Wire.Codecs;
with Generated_Profile_1_Text_Test_Codec;
with Profile_1_Text_Test_Types;
with System;

procedure Generated_Text_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Generated_Profile_1_Text_Test_Codec;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Profile_1_Text_Test_Types.Value;
   use type System.Address;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Source           : constant Codec.Value :=
     (UTF_8 => [16#41#, 16#C2#, 16#A2#, 16#E2#, 16#82#, 16#AC#, 0, 0], UTF_8_Length => 6);
   Empty_Source     : constant Codec.Value := (UTF_8 => [others => 0], UTF_8_Length => 0);
   Invalid_UTF_8    : constant Codec.Value := (UTF_8 => [16#C0#, 16#AF#, others => 0], UTF_8_Length => 2);
   Too_Many_Scalars : constant Codec.Value :=
     (UTF_8 => [16#41#, 16#42#, 16#43#, 16#44#, others => 0], UTF_8_Length => 4);
   Expected         : constant Wire.Octet_Array := [1, 6, 16#41#, 16#C2#, 16#A2#, 16#E2#, 16#82#, 16#AC#];
   Empty_Expected   : constant Wire.Octet_Array := [1, 0];
   Invalid_Encoded  : constant Wire.Octet_Array := [1, 2, 16#C0#, 16#AF#];
   Too_Many_Encoded : constant Wire.Octet_Array := [1, 4, 16#41#, 16#42#, 16#43#, 16#44#];
   Output           : Wire.Octet_Array (10 .. 21) := [others => 16#A5#];
   Before           : Wire.Octet_Array (10 .. 21);
   Payload          : aliased Wire.Octet_Array (20 .. 27) := Expected;
   Decoded          : Codec.Value;
   Size             : Wire.Byte_Count;
   Written          : Wire.Octet_Count;
   Measure_Result   : Codecs.Measure_Status;
   Encode_Result    : Codecs.Encode_Status;
   Decode_Result    : Codecs.Decode_Status;
   Calls            : Natural := 0;
   Expected_Address : System.Address := System.Null_Address;
   Same_Address     : Boolean := False;
   Observed         : Wire.Octet_Array (1 .. 6) := [others => 0];

   procedure Visit_UTF_8 (Value : Wire.Octet_Array) is
   begin
      Calls := Calls + 1;
      Observed := Value;
      Same_Address := Value'Address = Expected_Address;
   end Visit_UTF_8;

   procedure Observe is new Codec.Validate_And_Visit (Visit_UTF_8);

   Visitor_Error : exception;

   procedure Raise_From_Text (Value : Wire.Octet_Array) is
      pragma Unreferenced (Value);
   begin
      raise Visitor_Error;
   end Raise_From_Text;

   procedure Raising_Observe is new Codec.Validate_And_Visit (Raise_From_Text);

   Empty_Length : Natural := Natural'Last;

   procedure Visit_Empty (Value : Wire.Octet_Array) is
   begin
      Empty_Length := Value'Length;
   end Visit_Empty;

   procedure Observe_Empty is new Codec.Validate_And_Visit (Visit_Empty);

   Raised : Boolean := False;
begin
   Codec.Contract.Measure (Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 8
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (10),
      "generated text measure or maximum is incorrect");
   Codec.Contract.Measure (Invalid_UTF_8, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Invalid_Value and then Size = 0,
      "generated text measure accepted malformed UTF-8");
   Codec.Contract.Measure (Too_Many_Scalars, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Invalid_Value and then Size = 0,
      "generated text measure accepted too many Unicode scalars");

   Before := Output;
   Codec.Contract.Encode (Invalid_UTF_8, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Invalid_Value and then Written = 0 and then Output = Before,
      "invalid generated text encode modified its destination");
   Codec.Contract.Encode (Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 8 and then Output (10 .. 17) = Expected,
      "generated text codec emitted wrong canonical UTF-8 bytes");
   Codec.Contract.Encode (Empty_Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded and then Written = 2 and then Output (10 .. 11) = Empty_Expected,
      "generated text codec did not encode empty required text");

   Codec.Contract.Decode (Codec.Local_Schema, Expected, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Source, "generated text codec did not round trip");
   Codec.Contract.Decode (Codec.Local_Schema, Invalid_Encoded, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = Empty_Source,
      "generated text decode accepted malformed UTF-8 or partially published");
   Codec.Contract.Decode (Codec.Local_Schema, Too_Many_Encoded, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = Empty_Source,
      "generated text decode accepted too many scalars or partially published");

   Expected_Address := Payload (22)'Address;
   Observe (Codec.Local_Schema, Payload, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded
      and then Calls = 1
      and then Observed = Source.UTF_8 (1 .. 6)
      and then Same_Address,
      "generated text observer did not lend validated caller storage");
   Observe (Codec.Local_Schema, Invalid_Encoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Calls = 1,
      "malformed UTF-8 invoked the generated text callback");
   Observe_Empty (Codec.Local_Schema, Empty_Expected, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Empty_Length = 0,
      "generated text observer did not preserve empty text");

   begin
      Raising_Observe (Codec.Local_Schema, Payload, Decode_Result);
   exception
      when Visitor_Error =>
         Raised := True;
   end;
   Assert (Raised, "generated text observer converted an application exception into a status");
end Generated_Text_Codec_Smoke;
