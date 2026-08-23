with Ada.Streams;
with Flyology_Wire.Codecs.Contracts;
with Flyology_Wire.Identities;
with Flyology_Wire.Sizes;
with Interfaces;
with Wire_Test_Codec;

procedure Wire_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package IDs renames Flyology_Wire.Identities;
   package Sizes renames Flyology_Wire.Sizes;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Codec_Descriptor;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type IDs.Family_ID;
   use type IDs.Profile_ID;
   use type IDs.Scalar_Decode_Status;
   use type IDs.Scalar_ID_Bytes;
   use type IDs.Schema_Fingerprint;
   use type IDs.Schema_Identity;
   use type IDs.Schema_Identity_Bytes;
   use type IDs.Schema_Identity_Decode_Status;
   use type IDs.Schema_Revision;
   use type Interfaces.Unsigned_64;
   use type Sizes.Arithmetic_Status;
   use type Wire.Byte_Count;
   use type Wire.Octet;
   use type Wire.Octet_Count;
   use type Wire_Test_Codec.Value;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   generic
      with package Codec is new Flyology_Wire.Codecs.Contracts (<>);
   procedure Check_Static_Contract (Item : Codec.Value);

   procedure Check_Static_Contract (Item : Codec.Value) is
      Size   : Wire.Byte_Count;
      Status : Codecs.Measure_Status;
   begin
      Codec.Measure (Item, Size, Status);
      Assert (Status = Codecs.Measured and then Size > 0, "formal-package codec did not measure");
   end Check_Static_Contract;

   procedure Check_Test_Codec is new Check_Static_Contract (Wire_Test_Codec.Contract);

   Family               : constant IDs.Family_ID := [0 => 16#10#, 15 => 16#EF#, others => 0];
   Fingerprint          : constant IDs.Schema_Fingerprint := [0 => 16#AB#, 31 => 16#CD#, others => 0];
   Revision             : IDs.Schema_Revision;
   Profile              : IDs.Profile_ID;
   Scalar_Status        : IDs.Scalar_Decode_Status;
   Identity_Status      : IDs.Schema_Identity_Decode_Status;
   Decoded_Identity     : IDs.Schema_Identity;
   Revision_Bytes       : constant IDs.Scalar_ID_Bytes := IDs.To_Bytes (IDs.Schema_Revision (16#0102_0304#));
   Profile_Bytes        : constant IDs.Scalar_ID_Bytes := IDs.To_Bytes (IDs.Profile_ID (16#F0E0_D0C0#));
   Schema_Bytes         : constant IDs.Schema_Identity_Bytes :=
     IDs.To_Bytes (Wire_Test_Codec.Value_Descriptor.Schema);
   Invalid_Schema_Bytes : IDs.Schema_Identity_Bytes := Schema_Bytes;
   Source               : constant Wire_Test_Codec.Value :=
     (Code => 16#0102_0304_0506_0708#, Enabled => True);
   Invalid_Source       : constant Wire_Test_Codec.Value := (Code => 0, Enabled => False);
   Decoded_Value        : Wire_Test_Codec.Value;
   Size                 : Wire.Byte_Count;
   Written              : Wire.Octet_Count;
   Measure_Result       : Codecs.Measure_Status;
   Encode_Result        : Codecs.Encode_Status;
   Decode_Result        : Codecs.Decode_Status;
   Invalid_Descriptor   : Codecs.Codec_Descriptor := Wire_Test_Codec.Value_Descriptor;
   Wrong_Writer         : Codecs.Schema_Identity := Wire_Test_Codec.Value_Descriptor.Schema;
   Output               : Ada.Streams.Stream_Element_Array (10 .. 18) := [others => 16#CC#];
   Too_Small            : Wire.Octet_Array (20 .. 27) := [others => 16#DD#];
   Too_Small_Before     : constant Wire.Octet_Array := Too_Small;
   Noncanonical         : Wire.Octet_Array (30 .. 38);
   Wrong_Length         : constant Wire.Octet_Array (1 .. 8) := [others => 0];
   Arithmetic_Result    : Wire.Byte_Count;
   Arithmetic_Status    : Sizes.Arithmetic_Status;
   Accumulated          : Wire.Byte_Count;
begin
   Sizes.Add (Wire.Byte_Count'Last, 1, Arithmetic_Result, Arithmetic_Status);
   Assert
     (Arithmetic_Status = Sizes.Overflow and then Arithmetic_Result = 0,
      "size addition did not report overflow");
   Sizes.Add (Wire.Byte_Count'Last - 1, 1, Arithmetic_Result, Arithmetic_Status);
   Assert
     (Arithmetic_Status = Sizes.Computed and then Arithmetic_Result = Wire.Byte_Count'Last,
      "size addition rejected a representable result");
   Sizes.Multiply (Wire.Byte_Count'Last, 2, Arithmetic_Result, Arithmetic_Status);
   Assert
     (Arithmetic_Status = Sizes.Overflow and then Arithmetic_Result = 0,
      "size multiplication did not report overflow");
   Sizes.Multiply (Wire.Byte_Count'Last, 1, Arithmetic_Result, Arithmetic_Status);
   Assert
     (Arithmetic_Status = Sizes.Computed and then Arithmetic_Result = Wire.Byte_Count'Last,
      "size multiplication rejected the maximum result");
   Sizes.Multiply (0, Wire.Byte_Count'Last, Arithmetic_Result, Arithmetic_Status);
   Assert
     (Arithmetic_Status = Sizes.Computed and then Arithmetic_Result = 0, "zero size multiplication failed");
   Accumulated := Wire.Byte_Count'Last - 1;
   Sizes.Accumulate (Accumulated, 2, Arithmetic_Status);
   Assert
     (Arithmetic_Status = Sizes.Overflow and then Accumulated = Wire.Byte_Count'Last - 1,
      "failed size accumulation modified its total");
   Accumulated := 40;
   Sizes.Accumulate (Accumulated, 2, Arithmetic_Status);
   Assert
     (Arithmetic_Status = Sizes.Computed and then Accumulated = 42,
      "successful size accumulation did not publish its total");

   Assert (Family = IDs.Family_From_Bytes (IDs.To_Bytes (Family)), "family identity round trip failed");
   Assert
     (IDs.Is_Valid (Family) and then not IDs.Is_Valid (IDs.Family_ID'[others => 0]),
      "family sentinel validation failed");
   Assert
     (Fingerprint = IDs.Fingerprint_From_Bytes (IDs.To_Bytes (Fingerprint)),
      "fingerprint identity round trip failed");
   Assert
     (IDs.Is_Valid (Fingerprint) and then not IDs.Is_Valid (IDs.Schema_Fingerprint'[others => 0]),
      "fingerprint sentinel validation failed");

   Assert (Revision_Bytes = [0 => 1, 1 => 2, 2 => 3, 3 => 4], "schema revision is not canonical big endian");
   IDs.Revision_From_Bytes (Revision_Bytes, Revision, Scalar_Status);
   Assert
     (Scalar_Status = IDs.Decoded and then Revision = IDs.Schema_Revision (16#0102_0304#),
      "schema revision round trip failed");
   IDs.Revision_From_Bytes ([others => 0], Revision, Scalar_Status);
   Assert
     (Scalar_Status = IDs.Zero_Is_Invalid and then Revision = IDs.Schema_Revision'First,
      "zero schema revision did not fail closed");

   Assert
     (Profile_Bytes = [0 => 16#F0#, 1 => 16#E0#, 2 => 16#D0#, 3 => 16#C0#],
      "profile id is not canonical big endian");
   IDs.Profile_From_Bytes (Profile_Bytes, Profile, Scalar_Status);
   Assert
     (Scalar_Status = IDs.Decoded and then Profile = IDs.Profile_ID (16#F0E0_D0C0#),
      "profile id round trip failed");
   IDs.Profile_From_Bytes ([others => 0], Profile, Scalar_Status);
   Assert
     (Scalar_Status = IDs.Zero_Is_Invalid and then Profile = IDs.Profile_ID'First,
      "zero profile id did not fail closed");

   Assert
     (Schema_Bytes'Length = IDs.Schema_Identity_Length
      and then Schema_Bytes (0) = 1
      and then Schema_Bytes (16) = 16#A5#
      and then Schema_Bytes (48 .. 51) = [0, 0, 0, 1]
      and then Schema_Bytes (52 .. 55) = [16#FF#, 16#FF#, 16#FF#, 16#FF#],
      "schema identity does not use canonical field order");
   IDs.Schema_Identity_From_Bytes (Schema_Bytes, Decoded_Identity, Identity_Status);
   Assert
     (Identity_Status = IDs.Identity_Decoded
      and then Decoded_Identity = Wire_Test_Codec.Value_Descriptor.Schema,
      "schema identity round trip failed");

   Invalid_Schema_Bytes (0 .. 15) := [others => 0];
   IDs.Schema_Identity_From_Bytes (Invalid_Schema_Bytes, Decoded_Identity, Identity_Status);
   Assert
     (Identity_Status = IDs.Invalid_Family and then not IDs.Is_Valid (Decoded_Identity),
      "zero family bytes did not fail closed");
   Invalid_Schema_Bytes := Schema_Bytes;
   Invalid_Schema_Bytes (16 .. 47) := [others => 0];
   IDs.Schema_Identity_From_Bytes (Invalid_Schema_Bytes, Decoded_Identity, Identity_Status);
   Assert
     (Identity_Status = IDs.Invalid_Fingerprint and then not IDs.Is_Valid (Decoded_Identity),
      "zero fingerprint bytes did not fail closed");
   Invalid_Schema_Bytes := Schema_Bytes;
   Invalid_Schema_Bytes (48 .. 51) := [others => 0];
   IDs.Schema_Identity_From_Bytes (Invalid_Schema_Bytes, Decoded_Identity, Identity_Status);
   Assert
     (Identity_Status = IDs.Invalid_Revision and then not IDs.Is_Valid (Decoded_Identity),
      "zero revision bytes did not fail closed");
   Invalid_Schema_Bytes := Schema_Bytes;
   Invalid_Schema_Bytes (52 .. 55) := [others => 0];
   IDs.Schema_Identity_From_Bytes (Invalid_Schema_Bytes, Decoded_Identity, Identity_Status);
   Assert
     (Identity_Status = IDs.Invalid_Profile and then not IDs.Is_Valid (Decoded_Identity),
      "zero profile bytes did not fail closed");

   Assert (Codecs.Is_Valid (Wire_Test_Codec.Value_Descriptor), "test codec descriptor is invalid");
   Invalid_Descriptor.Schema.Fingerprint := [others => 0];
   Assert (not Codecs.Is_Valid (Invalid_Descriptor), "zero fingerprint descriptor was accepted");
   Invalid_Descriptor := Wire_Test_Codec.Value_Descriptor;
   Invalid_Descriptor.Schema.Family := [others => 0];
   Assert (not Codecs.Is_Valid (Invalid_Descriptor), "zero family descriptor was accepted");
   Invalid_Descriptor := Wire_Test_Codec.Value_Descriptor;
   Invalid_Descriptor.Maximum_Encoded_Size := (Known => False, Value => 1);
   Assert (not Codecs.Is_Valid (Invalid_Descriptor), "noncanonical unknown size was accepted");
   Assert
     (Wire_Test_Codec.Contract.Descriptor = Wire_Test_Codec.Value_Descriptor,
      "static contract lost its descriptor");
   Assert (Wire.Fits_In_Buffer (9) and then Wire.To_Octet_Count (9) = 9, "stream count conversion failed");

   Wire_Test_Codec.Contract.Measure (Source, Size, Measure_Result);
   Assert (Measure_Result = Codecs.Measured and then Size = 9, "exact measure failed");
   Wire_Test_Codec.Contract.Measure (Invalid_Source, Size, Measure_Result);
   Assert (Measure_Result = Codecs.Invalid_Value and then Size = 0, "invalid measure did not fail closed");

   Wire_Test_Codec.Contract.Encode (Source, Too_Small, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Destination_Too_Small and then Written = 0 and then Too_Small = Too_Small_Before,
      "short destination was modified or accepted");

   Wire_Test_Codec.Contract.Encode (Invalid_Source, Too_Small, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Invalid_Value and then Written = 0 and then Too_Small = Too_Small_Before,
      "invalid value encode modified its destination");

   Wire_Test_Codec.Contract.Encode (Source, Output, Written, Encode_Result);
   Assert (Encode_Result = Codecs.Encoded and then Written = 9, "caller-buffer encode failed");
   Assert
     (Output = [10 => 1, 11 => 2, 12 => 3, 13 => 4, 14 => 5, 15 => 6, 16 => 7, 17 => 8, 18 => 1],
      "caller-buffer encode did not produce canonical bytes");
   Wire_Test_Codec.Contract.Decode
     (Wire_Test_Codec.Value_Descriptor.Schema, Output, Decoded_Value, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded_Value.Code = Source.Code and then Decoded_Value.Enabled,
      "complete payload round trip failed");

   Noncanonical := Output;
   Noncanonical (Noncanonical'Last) := 2;
   Wire_Test_Codec.Contract.Decode
     (Wire_Test_Codec.Value_Descriptor.Schema, Noncanonical, Decoded_Value, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded_Value = (Code => 1, Enabled => False),
      "noncanonical payload partially published a value");

   Wire_Test_Codec.Contract.Decode
     (Wire_Test_Codec.Value_Descriptor.Schema, Wrong_Length, Decoded_Value, Decode_Result);
   Assert
     (Decode_Result = Codecs.Malformed and then Decoded_Value = (Code => 1, Enabled => False),
      "wrong-length payload partially published a value");

   Output := [others => 0];
   Wire_Test_Codec.Contract.Decode
     (Wire_Test_Codec.Value_Descriptor.Schema, Output, Decoded_Value, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded_Value = (Code => 1, Enabled => False),
      "invalid payload partially published a value");

   Wrong_Writer.Fingerprint := [0 => 16#5A#, others => 0];
   Wire_Test_Codec.Contract.Decode (Wrong_Writer, Output, Decoded_Value, Decode_Result);
   Assert
     (Decode_Result = Codecs.Incompatible and then Decoded_Value = (Code => 1, Enabled => False),
      "incompatible writer identity was accepted or partially published");

   Wrong_Writer.Fingerprint := [others => 0];
   Wire_Test_Codec.Contract.Decode (Wrong_Writer, Output, Decoded_Value, Decode_Result);
   Assert
     (Decode_Result = Codecs.Incompatible and then Decoded_Value = (Code => 1, Enabled => False),
      "invalid writer identity was accepted or partially published");

   Check_Test_Codec (Source);
end Wire_Smoke;
