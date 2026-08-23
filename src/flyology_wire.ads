with Ada.Streams;
with Interfaces;

--  Defines transport-independent bytes and sizes shared by Flyology wire
--  codecs. Octet_Array is exactly Ada.Streams.Stream_Element_Array so callers
--  can lend file, socket, or shared-memory buffers without conversion. The
--  package performs no I/O and allocates no storage.

package Flyology_Wire
  with Pure
is
   pragma
     Compile_Time_Error
       (Ada.Streams.Stream_Element'Size /= 8, "Flyology wire requires eight-bit Ada stream elements");

   --  One canonical wire byte, directly compatible with Ada stream storage.
   subtype Octet is Ada.Streams.Stream_Element;
   --  Index of one byte in caller-owned stream storage.
   subtype Octet_Offset is Ada.Streams.Stream_Element_Offset;
   --  Nonnegative byte count representable by caller-owned stream storage.
   subtype Octet_Count is Ada.Streams.Stream_Element_Count;
   --  Caller-owned contiguous bytes. Arbitrary lower bounds are supported.
   subtype Octet_Array is Ada.Streams.Stream_Element_Array;

   --  Fixed-width exact encoded size. A measured value may exceed the native
   --  index range even though no one buffer can hold it.
   type Byte_Count is new Interfaces.Unsigned_64;

   --  Report whether Size can be represented by Octet_Count.
   function Fits_In_Buffer (Size : Byte_Count) return Boolean
   is (Size <= Byte_Count (Octet_Count'Last));

   --  Convert a checked exact size into the Ada stream count used by buffer
   --  APIs.
   function To_Octet_Count (Size : Byte_Count) return Octet_Count
   is (Octet_Count (Size))
   with Pre => Fits_In_Buffer (Size);

end Flyology_Wire;
