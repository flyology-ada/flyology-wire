with Flyology_Wire.Sizes;
with Interfaces;

--  Allocation-free primitives for canonical tagged Profile 1. Cursors use
--  offsets relative to the supplied array and support arbitrary lower bounds.

package Flyology_Wire.Profiles.Tagged_Profile
  with Pure
is
   Max_Field_Tag : constant Interfaces.Unsigned_32 := 16#1FFF_FFFF#;

   subtype Tag_Number is Interfaces.Unsigned_32 range 0 .. Max_Field_Tag;
   subtype Field_Tag is Tag_Number range 1 .. Max_Field_Tag;
   No_Tag : constant Tag_Number := 0;

   subtype Varint_Length is Octet_Count range 1 .. 10;

   type Extent is record
      Start  : Octet_Count := 0;
      Length : Octet_Count := 0;
   end record;

   Empty_Extent : constant Extent := (others => 0);

   type Cursor_Status is (Cursor_Ready, Invalid_Extent);

   type Read_Cursor is private;

   procedure Initialize (Cursor : out Read_Cursor; Input : Octet_Array);

   procedure Initialize
     (Cursor : out Read_Cursor; Input : Octet_Array; Region : Extent; Status : out Cursor_Status);

   function Consumed (Cursor : Read_Cursor) return Octet_Count;
   function Remaining (Cursor : Read_Cursor) return Octet_Count;
   function At_End (Cursor : Read_Cursor) return Boolean;

   type Read_Status is
     (Read,
      Truncated,
      Value_Overflow,
      Noncanonical,
      Invalid_Boolean,
      Invalid_Tag,
      Tag_Order_Error,
      Extent_Outside_Container);

   procedure Read_Unsigned
     (Input  : Octet_Array;
      Cursor : in out Read_Cursor;
      Value  : out Interfaces.Unsigned_64;
      Status : out Read_Status);

   procedure Read_Signed
     (Input  : Octet_Array;
      Cursor : in out Read_Cursor;
      Value  : out Interfaces.Integer_64;
      Status : out Read_Status);

   procedure Read_Boolean
     (Input : Octet_Array; Cursor : in out Read_Cursor; Value : out Boolean; Status : out Read_Status);

   --  Read a shortest-varint length and reserve exactly that many octets.
   --  Cursor remains unchanged on failure.
   procedure Read_Length_Delimited
     (Input : Octet_Array; Cursor : in out Read_Cursor; Value : out Extent; Status : out Read_Status);

   --  Read one strictly increasing field header and reserve its complete value
   --  extent. Cursor and Previous remain unchanged on failure.
   procedure Read_Field_Header
     (Input    : Octet_Array;
      Cursor   : in out Read_Cursor;
      Previous : in out Tag_Number;
      Tag      : out Field_Tag;
      Value    : out Extent;
      Status   : out Read_Status);

   type Write_Cursor is private;

   procedure Initialize (Cursor : out Write_Cursor; Output : Octet_Array);

   procedure Initialize
     (Cursor : out Write_Cursor; Output : Octet_Array; Region : Extent; Status : out Cursor_Status);

   function Consumed (Cursor : Write_Cursor) return Octet_Count;
   function Remaining (Cursor : Write_Cursor) return Octet_Count;
   function At_End (Cursor : Write_Cursor) return Boolean;

   type Write_Status is (Wrote, Destination_Too_Small, Invalid_Tag, Tag_Order_Error);

   function Unsigned_Size (Value : Interfaces.Unsigned_64) return Varint_Length;

   procedure Write_Unsigned
     (Output : in out Octet_Array;
      Cursor : in out Write_Cursor;
      Value  : Interfaces.Unsigned_64;
      Status : out Write_Status);

   procedure Write_Signed
     (Output : in out Octet_Array;
      Cursor : in out Write_Cursor;
      Value  : Interfaces.Integer_64;
      Status : out Write_Status);

   procedure Write_Boolean
     (Output : in out Octet_Array; Cursor : in out Write_Cursor; Value : Boolean; Status : out Write_Status);

   --  Write a shortest-varint length, reserve the value extent, and advance
   --  Cursor past it. Output and Cursor remain unchanged on failure.
   procedure Write_Length_Delimited
     (Output       : in out Octet_Array;
      Cursor       : in out Write_Cursor;
      Value_Length : Byte_Count;
      Value        : out Extent;
      Status       : out Write_Status);

   --  Write one strictly increasing field header, reserve its complete value
   --  extent, and advance Cursor past that value. The caller initializes a
   --  nested writer over Value and fills it after successful preflight.
   procedure Write_Field_Header
     (Output       : in out Octet_Array;
      Cursor       : in out Write_Cursor;
      Previous     : in out Tag_Number;
      Tag          : Tag_Number;
      Value_Length : Byte_Count;
      Value        : out Extent;
      Status       : out Write_Status);

   procedure Measure_Field
     (Tag          : Field_Tag;
      Value_Length : Byte_Count;
      Size         : out Byte_Count;
      Status       : out Sizes.Arithmetic_Status);

   procedure Measure_Length_Delimited
     (Value_Length : Byte_Count; Size : out Byte_Count; Status : out Sizes.Arithmetic_Status);

   type UTF_8_Status is (Valid_UTF_8, Invalid_UTF_8, Invalid_UTF_8_Extent);

   --  Validate one complete extent as shortest-form Unicode UTF-8, excluding
   --  surrogate code points and values above U+10FFFF.
   procedure Validate_UTF_8 (Input : Octet_Array; Region : Extent; Status : out UTF_8_Status);

   function ZigZag_Encode (Value : Interfaces.Integer_64) return Interfaces.Unsigned_64;
   function ZigZag_Decode (Value : Interfaces.Unsigned_64) return Interfaces.Integer_64;

private
   type Read_Cursor is record
      First : Octet_Count := 0;
      Next  : Octet_Count := 0;
      Limit : Octet_Count := 0;
   end record;

   type Write_Cursor is record
      First : Octet_Count := 0;
      Next  : Octet_Count := 0;
      Limit : Octet_Count := 0;
   end record;
end Flyology_Wire.Profiles.Tagged_Profile;
