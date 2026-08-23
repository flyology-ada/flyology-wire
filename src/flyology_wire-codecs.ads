with Flyology_Wire.Identities;

--  Common allocation-free codec descriptors and outcomes. Transport framing,
--  routing, correlation, sessions, and I/O remain outside this hierarchy.

package Flyology_Wire.Codecs
  with Pure
is
   package Identities renames Flyology_Wire.Identities;

   --  Optional statically known encoded-size ceiling. Value is zero when the
   --  codec has no static maximum.
   type Size_Bound is record
      Known : Boolean := False;
      Value : Byte_Count := 0;
   end record;

   Unknown_Size : constant Size_Bound := (Known => False, Value => 0);

   --  Construct a known static encoded-size ceiling.
   function Bounded (Value : Byte_Count) return Size_Bound
   is ((Known => True, Value => Value));

   --  Report whether an unknown bound uses its canonical zero value, or a
   --  known bound fits one caller-provided stream array on this target.
   function Is_Valid (Item : Size_Bound) return Boolean
   is ((if Item.Known then Fits_In_Buffer (Item.Value) else Item.Value = 0));

   subtype Schema_Identity is Identities.Schema_Identity;

   function Is_Valid (Item : Schema_Identity) return Boolean renames Identities.Is_Valid;

   --  Stable identity and boundedness contract of one local codec.
   type Codec_Descriptor is record
      Schema               : Schema_Identity;
      Maximum_Encoded_Size : Size_Bound := Unknown_Size;
   end record;

   --  Report whether the descriptor has a valid schema identity and a
   --  representable static ceiling when one is declared.
   function Is_Valid (Item : Codec_Descriptor) return Boolean
   is (Is_Valid (Item.Schema) and then Is_Valid (Item.Maximum_Encoded_Size));

   --  Exact-measure outcome.
   type Measure_Status is (Measured, Invalid_Value, Size_Overflow);

   --  Caller-buffer encode outcome. A failed operation publishes Written = 0
   --  and must not modify Output.
   type Encode_Status is (Encoded, Invalid_Value, Size_Overflow, Destination_Too_Small);

   --  Complete-payload decode outcome. A failed operation publishes a harmless
   --  initialized destination value rather than a partially decoded value.
   type Decode_Status is (Decoded, Malformed, Noncanonical, Incompatible, Limit_Exceeded, Invalid_Value);
end Flyology_Wire.Codecs;
