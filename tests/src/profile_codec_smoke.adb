with Ada.Streams;
with Flyology_Wire.Codecs;
with Interfaces;
with Profile_1_Test_Codec;

procedure Profile_Codec_Smoke is
   package Wire renames Flyology_Wire;
   package Codecs renames Flyology_Wire.Codecs;
   package Codec renames Profile_1_Test_Codec;

   use type Ada.Streams.Stream_Element_Array;
   use type Codecs.Decode_Status;
   use type Codecs.Encode_Status;
   use type Codecs.Measure_Status;
   use type Codecs.Size_Bound;
   use type Codec.Value;
   use type Wire.Byte_Count;
   use type Wire.Octet_Count;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   Source            : constant Codec.Value := (Code => 300, Enabled => True);
   Maximum_Source    : constant Codec.Value := (Code => Interfaces.Unsigned_64'Last, Enabled => True);
   Decoded           : Codec.Value;
   Size              : Wire.Byte_Count;
   Written           : Wire.Octet_Count;
   Measure_Result    : Codecs.Measure_Status;
   Encode_Result     : Codecs.Encode_Status;
   Decode_Result     : Codecs.Decode_Status;
   Output            : Wire.Octet_Array (20 .. 29) := [others => 16#CC#];
   Short             : Wire.Octet_Array (1 .. 6) := [others => 16#DD#];
   Short_Before      : constant Wire.Octet_Array := Short;
   Exact_Payload     : constant Wire.Octet_Array := [1, 2, 16#AC#, 2, 2, 1, 1];
   Older_Payload     : constant Wire.Octet_Array := [1, 2, 16#AC#, 2];
   Future_Payload    : constant Wire.Octet_Array := [1, 2, 16#AC#, 2, 2, 1, 1, 3, 1, 16#FE#];
   Missing_Required  : constant Wire.Octet_Array := [2, 1, 1];
   Duplicate_Tag     : constant Wire.Octet_Array := [1, 1, 1, 1, 1, 2];
   Trailing_Value    : constant Wire.Octet_Array := [1, 2, 1, 0, 2, 1, 1];
   Truncated_Varint  : constant Wire.Octet_Array := [1, 1, 16#80#];
   Overlong_Varint   : constant Wire.Octet_Array := [1, 2, 16#81#, 0, 2, 1, 1];
   Invalid_Extent    : constant Wire.Octet_Array := [1, 2, 1];
   Invalid_Boolean   : constant Wire.Octet_Array := [1, 1, 1, 2, 1, 2];
   Zero_Code         : constant Wire.Octet_Array := [1, 1, 0, 2, 1, 1];
   Unknown_Future    : constant Wire.Octet_Array := [1, 1, 1, 2, 1, 1, 4, 0];
   Future_Incomplete : constant Wire.Octet_Array := [1, 1, 1, 3, 0];
   Invalid_Source    : constant Codec.Value := (Code => 0, Enabled => True);
   Invalid_Output    : Wire.Octet_Array (1 .. 8) := [others => 16#BA#];
   Invalid_Before    : constant Wire.Octet_Array := Invalid_Output;
   Wrong_Writer      : Codecs.Schema_Identity := Codec.Local_Schema;
begin
   Codec.Contract.Measure (Source, Size, Measure_Result);
   Assert (Measure_Result = Codecs.Measured and then Size = 7, "Profile 1 measure is not exact");

   Codec.Contract.Measure (Maximum_Source, Size, Measure_Result);
   Assert
     (Measure_Result = Codecs.Measured
      and then Size = 15
      and then Codec.Value_Descriptor.Maximum_Encoded_Size = Codecs.Bounded (Size),
      "Profile 1 static maximum does not bound exact measurement");

   Codec.Contract.Encode (Source, Short, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Destination_Too_Small and then Written = 0 and then Short = Short_Before,
      "short Profile 1 encode modified output");

   Codec.Contract.Encode (Source, Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Encoded
      and then Written = 7
      and then Output (20 .. 26) = Exact_Payload
      and then Output (27 .. 29) = [27 => 16#CC#, 28 => 16#CC#, 29 => 16#CC#],
      "Profile 1 encode has wrong canonical bytes or extent");

   Codec.Contract.Encode (Invalid_Source, Invalid_Output, Written, Encode_Result);
   Assert
     (Encode_Result = Codecs.Invalid_Value and then Written = 0 and then Invalid_Output = Invalid_Before,
      "invalid Profile 1 value modified output");

   Codec.Contract.Decode (Codec.Local_Schema, Exact_Payload, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Source, "exact Profile 1 payload did not round trip");

   Codec.Contract.Decode (Codec.Older_Schema, Older_Payload, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = (Code => 300, Enabled => False),
      "older compatible payload did not apply its construction default");

   Codec.Contract.Decode (Codec.Future_Schema, Future_Payload, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Decoded and then Decoded = Source,
      "future compatible payload did not skip its approved tag");

   Codec.Contract.Decode (Codec.Local_Schema, Future_Payload, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "exact schema accepted an unknown future tag");

   Codec.Contract.Decode (Codec.Older_Schema, Exact_Payload, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "older writer accepted a field absent from its schema");

   Codec.Contract.Decode (Codec.Local_Schema, Missing_Required, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = (Code => 1, Enabled => False),
      "missing required field partially published a value");

   Codec.Contract.Decode (Codec.Local_Schema, Duplicate_Tag, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "duplicate field tag was accepted or partially published");

   Codec.Contract.Decode (Codec.Local_Schema, Trailing_Value, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "field value with trailing bytes was accepted or partially published");

   Codec.Contract.Decode (Codec.Local_Schema, Truncated_Varint, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Malformed and then Decoded = (Code => 1, Enabled => False),
      "truncated field value was misclassified or partially published");

   Codec.Contract.Decode (Codec.Local_Schema, Overlong_Varint, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "overlong scalar varint was accepted or partially published");

   Codec.Contract.Decode (Codec.Local_Schema, Invalid_Extent, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Malformed and then Decoded = (Code => 1, Enabled => False),
      "field extent outside the payload was misclassified or partially published");

   Codec.Contract.Decode (Codec.Local_Schema, Invalid_Boolean, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "invalid boolean was accepted or partially published");

   Codec.Contract.Decode (Codec.Local_Schema, Zero_Code, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = (Code => 1, Enabled => False),
      "application-invalid scalar was accepted or partially published");

   Codec.Contract.Decode (Codec.Future_Schema, Unknown_Future, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Noncanonical and then Decoded = (Code => 1, Enabled => False),
      "future writer accepted a tag absent from its approved edge");

   Codec.Contract.Decode (Codec.Future_Schema, Future_Incomplete, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Invalid_Value and then Decoded = (Code => 1, Enabled => False),
      "future writer omitted a required local field");

   Wrong_Writer.Fingerprint := [0 => 16#EE#, others => 0];
   Codec.Contract.Decode (Wrong_Writer, Exact_Payload, Decoded, Decode_Result);
   Assert
     (Decode_Result = Codecs.Incompatible and then Decoded = (Code => 1, Enabled => False),
      "unlisted writer was accepted or partially published");
end Profile_Codec_Smoke;
