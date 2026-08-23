--  Statically binds one definite Ada value type to one wire codec. Generated
--  codecs and handwritten adapters instantiate this same package; remoting can
--  accept an instance as a generic formal package without runtime dispatch.

generic
   type Value_Type is private;
   Value_Descriptor : Codecs.Codec_Descriptor;
   with
     procedure Measure_Value (Item : Value_Type; Size : out Byte_Count; Status : out Codecs.Measure_Status);
   with
     procedure Encode_Value
       (Item    : Value_Type;
        Output  : in out Octet_Array;
        Written : out Octet_Count;
        Status  : out Codecs.Encode_Status);
   with
     procedure Decode_Value
       (Writer : Codecs.Schema_Identity;
        Input  : Octet_Array;
        Item   : out Value_Type;
        Status : out Codecs.Decode_Status);
package Flyology_Wire.Codecs.Contracts is
   --  Ada value represented by this codec.
   subtype Value is Value_Type;

   --  Stable semantic and encoding identity.
   Descriptor : constant Codecs.Codec_Descriptor := Value_Descriptor;

   --  Measure the exact encoded size. Failure returns Size = 0.
   procedure Measure (Item : Value; Size : out Byte_Count; Status : out Codecs.Measure_Status)
   renames Measure_Value;

   --  Encode into arbitrary-bound caller storage. Failure returns Written = 0
   --  and leaves Output unchanged.
   procedure Encode
     (Item : Value; Output : in out Octet_Array; Written : out Octet_Count; Status : out Codecs.Encode_Status)
   renames Encode_Value;

   --  Decode one complete payload transactionally under the writer's schema
   --  identity. Failure returns a harmless initialized Item selected by the
   --  codec. An unrecognized identity returns Incompatible.
   procedure Decode
     (Writer : Codecs.Schema_Identity;
      Input  : Octet_Array;
      Item   : out Value;
      Status : out Codecs.Decode_Status)
   renames Decode_Value;
end Flyology_Wire.Codecs.Contracts;
