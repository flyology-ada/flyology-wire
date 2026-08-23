package body Flyology_Wire.Profiles.Tagged_Profile is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Octet;
   use type Octet_Count;
   use type Sizes.Arithmetic_Status;

   procedure Visit_Extent (Input : Octet_Array; Region : Extent; Status : out Cursor_Status) is
      First : Octet_Offset;
      Last  : Octet_Offset;
   begin
      if Region.Start > Input'Length or else Region.Length > Input'Length - Region.Start then
         Status := Invalid_Extent;
      elsif Region.Length = 0 then
         Status := Cursor_Ready;
         Visit (Input (1 .. 0));
      else
         First := Input'First + Octet_Offset (Region.Start);
         Last := First + Octet_Offset (Region.Length - 1);
         Status := Cursor_Ready;
         Visit (Input (First .. Last));
      end if;
   end Visit_Extent;

   procedure Initialize (Cursor : out Read_Cursor; Input : Octet_Array) is
   begin
      Cursor := (First => 0, Next => 0, Limit => Input'Length);
   end Initialize;

   procedure Initialize
     (Cursor : out Read_Cursor; Input : Octet_Array; Region : Extent; Status : out Cursor_Status) is
   begin
      Cursor := (others => 0);
      if Region.Start > Input'Length or else Region.Length > Input'Length - Region.Start then
         Status := Invalid_Extent;
      else
         Cursor := (First => Region.Start, Next => Region.Start, Limit => Region.Start + Region.Length);
         Status := Cursor_Ready;
      end if;
   end Initialize;

   function Consumed (Cursor : Read_Cursor) return Octet_Count
   is (Cursor.Next - Cursor.First);

   function Remaining (Cursor : Read_Cursor) return Octet_Count
   is (Cursor.Limit - Cursor.Next);

   function At_End (Cursor : Read_Cursor) return Boolean
   is (Cursor.Next = Cursor.Limit);

   function Is_Valid (Cursor : Read_Cursor; Length : Octet_Count) return Boolean
   is (Cursor.First <= Cursor.Next and then Cursor.Next <= Cursor.Limit and then Cursor.Limit <= Length);

   function Take (Input : Octet_Array; Cursor : in out Read_Cursor; Value : out Octet) return Boolean is
   begin
      Value := 0;
      if Cursor.Next = Cursor.Limit then
         return False;
      end if;

      Value := Input (Input'First + Octet_Offset (Cursor.Next));
      Cursor.Next := Cursor.Next + 1;
      return True;
   end Take;

   procedure Read_Unsigned
     (Input  : Octet_Array;
      Cursor : in out Read_Cursor;
      Value  : out Interfaces.Unsigned_64;
      Status : out Read_Status)
   is
      Candidate : Read_Cursor := Cursor;
      Result    : Interfaces.Unsigned_64 := 0;
      Current   : Octet;
      Payload   : Interfaces.Unsigned_64;
   begin
      Value := 0;
      if not Is_Valid (Candidate, Input'Length) then
         Status := Extent_Outside_Container;
         return;
      end if;
      for Group in Natural range 0 .. 9 loop
         if not Take (Input, Candidate, Current) then
            Status := Truncated;
            return;
         end if;

         Payload := Interfaces.Unsigned_64 (Current and 16#7F#);
         if Group = 9 and then Payload > 1 then
            Status := Value_Overflow;
            return;
         end if;
         Result := Result or Interfaces.Shift_Left (Payload, Group * 7);

         if (Current and 16#80#) = 0 then
            if Group > 0 and then Payload = 0 then
               Status := Noncanonical;
               return;
            end if;
            Cursor := Candidate;
            Value := Result;
            Status := Read;
            return;
         elsif Group = 9 then
            Status := Value_Overflow;
            return;
         end if;
      end loop;
      Status := Value_Overflow;
   end Read_Unsigned;

   function ZigZag_Encode (Value : Interfaces.Integer_64) return Interfaces.Unsigned_64 is
   begin
      if Value >= 0 then
         return Interfaces.Unsigned_64 (Value) * 2;
      else
         return Interfaces.Unsigned_64 (-(Value + 1)) * 2 + 1;
      end if;
   end ZigZag_Encode;

   function ZigZag_Decode (Value : Interfaces.Unsigned_64) return Interfaces.Integer_64 is
      Magnitude : constant Interfaces.Unsigned_64 := Value / 2;
   begin
      if Value mod 2 = 0 then
         return Interfaces.Integer_64 (Magnitude);
      else
         return -Interfaces.Integer_64 (Magnitude) - 1;
      end if;
   end ZigZag_Decode;

   procedure Read_Signed
     (Input  : Octet_Array;
      Cursor : in out Read_Cursor;
      Value  : out Interfaces.Integer_64;
      Status : out Read_Status)
   is
      Encoded : Interfaces.Unsigned_64;
   begin
      Value := 0;
      Read_Unsigned (Input, Cursor, Encoded, Status);
      if Status = Read then
         Value := ZigZag_Decode (Encoded);
      end if;
   end Read_Signed;

   procedure Read_Boolean
     (Input : Octet_Array; Cursor : in out Read_Cursor; Value : out Boolean; Status : out Read_Status)
   is
      Candidate : Read_Cursor := Cursor;
      Current   : Octet;
   begin
      Value := False;
      if not Is_Valid (Candidate, Input'Length) then
         Status := Extent_Outside_Container;
      elsif not Take (Input, Candidate, Current) then
         Status := Truncated;
      elsif Current > 1 then
         Status := Invalid_Boolean;
      else
         Cursor := Candidate;
         Value := Current = 1;
         Status := Read;
      end if;
   end Read_Boolean;

   procedure Read_Octets
     (Input  : Octet_Array;
      Cursor : in out Read_Cursor;
      Value  : in out Octet_Array;
      Count  : Octet_Count;
      Status : out Read_Status) is
   begin
      if Count > Remaining (Cursor) then
         Status := Truncated;
         return;
      elsif Count > Value'Length then
         Status := Destination_Too_Small;
         return;
      end if;

      if Count > 0 then
         for Offset in Octet_Count range 0 .. Count - 1 loop
            Value (Value'First + Octet_Offset (Offset)) :=
              Input (Input'First + Octet_Offset (Cursor.Next + Offset));
         end loop;
         Cursor.Next := Cursor.Next + Count;
      end if;
      Status := Read;
   end Read_Octets;

   procedure Read_Length_Delimited
     (Input : Octet_Array; Cursor : in out Read_Cursor; Value : out Extent; Status : out Read_Status)
   is
      Candidate : Read_Cursor := Cursor;
      Length    : Interfaces.Unsigned_64;
   begin
      Value := Empty_Extent;
      Read_Unsigned (Input, Candidate, Length, Status);
      if Status /= Read then
         return;
      elsif Length > Interfaces.Unsigned_64 (Remaining (Candidate)) then
         Status := Extent_Outside_Container;
         return;
      end if;

      Value := (Start => Candidate.Next, Length => Octet_Count (Length));
      Candidate.Next := Candidate.Next + Value.Length;
      Cursor := Candidate;
      Status := Read;
   end Read_Length_Delimited;

   procedure Read_Field_Header
     (Input    : Octet_Array;
      Cursor   : in out Read_Cursor;
      Previous : in out Tag_Number;
      Tag      : out Field_Tag;
      Value    : out Extent;
      Status   : out Read_Status)
   is
      Candidate : Read_Cursor := Cursor;
      Raw_Tag   : Interfaces.Unsigned_64;
      Length    : Interfaces.Unsigned_64;
   begin
      Tag := Field_Tag'First;
      Value := Empty_Extent;
      Read_Unsigned (Input, Candidate, Raw_Tag, Status);
      if Status /= Read then
         return;
      elsif Raw_Tag = 0 or else Raw_Tag > Interfaces.Unsigned_64 (Max_Field_Tag) then
         Status := Invalid_Tag;
         return;
      elsif Raw_Tag <= Interfaces.Unsigned_64 (Previous) then
         Status := Tag_Order_Error;
         return;
      end if;

      Read_Unsigned (Input, Candidate, Length, Status);
      if Status /= Read then
         return;
      elsif Length > Interfaces.Unsigned_64 (Remaining (Candidate)) then
         Status := Extent_Outside_Container;
         return;
      end if;

      Tag := Field_Tag (Raw_Tag);
      Value := (Start => Candidate.Next, Length => Octet_Count (Length));
      Candidate.Next := Candidate.Next + Value.Length;
      Cursor := Candidate;
      Previous := Tag_Number (Tag);
      Status := Read;
   end Read_Field_Header;

   procedure Initialize (Cursor : out Write_Cursor; Output : Octet_Array) is
   begin
      Cursor := (First => 0, Next => 0, Limit => Output'Length);
   end Initialize;

   procedure Initialize
     (Cursor : out Write_Cursor; Output : Octet_Array; Region : Extent; Status : out Cursor_Status) is
   begin
      Cursor := (others => 0);
      if Region.Start > Output'Length or else Region.Length > Output'Length - Region.Start then
         Status := Invalid_Extent;
      else
         Cursor := (First => Region.Start, Next => Region.Start, Limit => Region.Start + Region.Length);
         Status := Cursor_Ready;
      end if;
   end Initialize;

   function Consumed (Cursor : Write_Cursor) return Octet_Count
   is (Cursor.Next - Cursor.First);

   function Remaining (Cursor : Write_Cursor) return Octet_Count
   is (Cursor.Limit - Cursor.Next);

   function At_End (Cursor : Write_Cursor) return Boolean
   is (Cursor.Next = Cursor.Limit);

   function Is_Valid (Cursor : Write_Cursor; Length : Octet_Count) return Boolean
   is (Cursor.First <= Cursor.Next and then Cursor.Next <= Cursor.Limit and then Cursor.Limit <= Length);

   function Unsigned_Size (Value : Interfaces.Unsigned_64) return Varint_Length is
      Rest   : Interfaces.Unsigned_64 := Value;
      Result : Varint_Length := 1;
   begin
      while Rest >= 16#80# loop
         Rest := Interfaces.Shift_Right (Rest, 7);
         Result := Result + 1;
      end loop;
      return Result;
   end Unsigned_Size;

   procedure Put_Unsigned
     (Output : in out Octet_Array; Cursor : in out Write_Cursor; Value : Interfaces.Unsigned_64)
   is
      Rest : Interfaces.Unsigned_64 := Value;
      Byte : Octet;
   begin
      loop
         Byte := Octet (Rest and 16#7F#);
         Rest := Interfaces.Shift_Right (Rest, 7);
         if Rest /= 0 then
            Byte := Byte or 16#80#;
         end if;
         Output (Output'First + Octet_Offset (Cursor.Next)) := Byte;
         Cursor.Next := Cursor.Next + 1;
         exit when Rest = 0;
      end loop;
   end Put_Unsigned;

   procedure Write_Unsigned
     (Output : in out Octet_Array;
      Cursor : in out Write_Cursor;
      Value  : Interfaces.Unsigned_64;
      Status : out Write_Status)
   is
      Required : constant Varint_Length := Unsigned_Size (Value);
   begin
      if not Is_Valid (Cursor, Output'Length) or else Required > Remaining (Cursor) then
         Status := Destination_Too_Small;
      else
         Put_Unsigned (Output, Cursor, Value);
         Status := Wrote;
      end if;
   end Write_Unsigned;

   procedure Write_Signed
     (Output : in out Octet_Array;
      Cursor : in out Write_Cursor;
      Value  : Interfaces.Integer_64;
      Status : out Write_Status) is
   begin
      Write_Unsigned (Output, Cursor, ZigZag_Encode (Value), Status);
   end Write_Signed;

   procedure Write_Boolean
     (Output : in out Octet_Array; Cursor : in out Write_Cursor; Value : Boolean; Status : out Write_Status)
   is
   begin
      if not Is_Valid (Cursor, Output'Length) or else Remaining (Cursor) = 0 then
         Status := Destination_Too_Small;
      else
         Output (Output'First + Octet_Offset (Cursor.Next)) := Octet (Boolean'Pos (Value));
         Cursor.Next := Cursor.Next + 1;
         Status := Wrote;
      end if;
   end Write_Boolean;

   procedure Write_Octets
     (Output : in out Octet_Array;
      Cursor : in out Write_Cursor;
      Value  : Octet_Array;
      Count  : Octet_Count;
      Status : out Write_Status) is
   begin
      if Count > Remaining (Cursor) or else Count > Value'Length then
         Status := Destination_Too_Small;
         return;
      end if;

      if Count > 0 then
         for Offset in Octet_Count range 0 .. Count - 1 loop
            Output (Output'First + Octet_Offset (Cursor.Next + Offset)) :=
              Value (Value'First + Octet_Offset (Offset));
         end loop;
         Cursor.Next := Cursor.Next + Count;
      end if;
      Status := Wrote;
   end Write_Octets;

   procedure Write_Length_Delimited
     (Output       : in out Octet_Array;
      Cursor       : in out Write_Cursor;
      Value_Length : Byte_Count;
      Value        : out Extent;
      Status       : out Write_Status)
   is
      Length_Size : constant Varint_Length := Unsigned_Size (Interfaces.Unsigned_64 (Value_Length));
      Candidate   : Write_Cursor := Cursor;
   begin
      Value := Empty_Extent;
      if not Is_Valid (Candidate, Output'Length)
        or else Length_Size > Remaining (Candidate)
        or else Value_Length > Byte_Count (Remaining (Candidate) - Length_Size)
      then
         Status := Destination_Too_Small;
      else
         Put_Unsigned (Output, Candidate, Interfaces.Unsigned_64 (Value_Length));
         Value := (Start => Candidate.Next, Length => Octet_Count (Value_Length));
         Candidate.Next := Candidate.Next + Value.Length;
         Cursor := Candidate;
         Status := Wrote;
      end if;
   end Write_Length_Delimited;

   procedure Write_Field_Header
     (Output       : in out Octet_Array;
      Cursor       : in out Write_Cursor;
      Previous     : in out Tag_Number;
      Tag          : Tag_Number;
      Value_Length : Byte_Count;
      Value        : out Extent;
      Status       : out Write_Status)
   is
      Tag_Size    : constant Varint_Length := Unsigned_Size (Interfaces.Unsigned_64 (Tag));
      Length_Size : constant Varint_Length := Unsigned_Size (Interfaces.Unsigned_64 (Value_Length));
      Header_Size : constant Octet_Count := Tag_Size + Length_Size;
      Candidate   : Write_Cursor := Cursor;
   begin
      Value := Empty_Extent;
      if Tag = No_Tag then
         Status := Invalid_Tag;
      elsif Tag <= Previous then
         Status := Tag_Order_Error;
      elsif not Is_Valid (Candidate, Output'Length)
        or else Header_Size > Remaining (Candidate)
        or else Value_Length > Byte_Count (Remaining (Candidate) - Header_Size)
      then
         Status := Destination_Too_Small;
      else
         Put_Unsigned (Output, Candidate, Interfaces.Unsigned_64 (Tag));
         Put_Unsigned (Output, Candidate, Interfaces.Unsigned_64 (Value_Length));
         Value := (Start => Candidate.Next, Length => Octet_Count (Value_Length));
         Candidate.Next := Candidate.Next + Value.Length;
         Cursor := Candidate;
         Previous := Tag;
         Status := Wrote;
      end if;
   end Write_Field_Header;

   procedure Measure_Field
     (Tag : Field_Tag; Value_Length : Byte_Count; Size : out Byte_Count; Status : out Sizes.Arithmetic_Status)
   is
   begin
      Size := Value_Length;
      Sizes.Accumulate (Size, Byte_Count (Unsigned_Size (Interfaces.Unsigned_64 (Tag))), Status);
      if Status = Sizes.Computed then
         Sizes.Accumulate (Size, Byte_Count (Unsigned_Size (Interfaces.Unsigned_64 (Value_Length))), Status);
      end if;
      if Status = Sizes.Overflow then
         Size := 0;
      end if;
   end Measure_Field;

   procedure Measure_Length_Delimited
     (Value_Length : Byte_Count; Size : out Byte_Count; Status : out Sizes.Arithmetic_Status) is
   begin
      Size := Value_Length;
      Sizes.Accumulate (Size, Byte_Count (Unsigned_Size (Interfaces.Unsigned_64 (Value_Length))), Status);
      if Status = Sizes.Overflow then
         Size := 0;
      end if;
   end Measure_Length_Delimited;

   function Is_Continuation (Value : Octet) return Boolean
   is (Value in 16#80# .. 16#BF#);

   procedure Validate_UTF_8
     (Input : Octet_Array; Region : Extent; Scalar_Count : out Octet_Count; Status : out UTF_8_Status)
   is
      Cursor        : Read_Cursor;
      Cursor_Result : Cursor_Status;
      Count         : Octet_Count := 0;
      First         : Octet;
      Second        : Octet;
      Third         : Octet;
      Fourth        : Octet;

      function Next (Value : out Octet) return Boolean is
      begin
         return Take (Input, Cursor, Value);
      end Next;
   begin
      Scalar_Count := 0;
      Initialize (Cursor, Input, Region, Cursor_Result);
      if Cursor_Result /= Cursor_Ready then
         Status := Invalid_UTF_8_Extent;
         return;
      end if;

      while not At_End (Cursor) loop
         if not Next (First) then
            Status := Invalid_UTF_8;
            return;
         elsif First <= 16#7F# then
            null;
         elsif First in 16#C2# .. 16#DF# then
            if not Next (Second) or else not Is_Continuation (Second) then
               Status := Invalid_UTF_8;
               return;
            end if;
         elsif First = 16#E0# then
            if not Next (Second)
              or else Second not in 16#A0# .. 16#BF#
              or else not Next (Third)
              or else not Is_Continuation (Third)
            then
               Status := Invalid_UTF_8;
               return;
            end if;
         elsif First in 16#E1# .. 16#EC# or else First in 16#EE# .. 16#EF# then
            if not Next (Second)
              or else not Is_Continuation (Second)
              or else not Next (Third)
              or else not Is_Continuation (Third)
            then
               Status := Invalid_UTF_8;
               return;
            end if;
         elsif First = 16#ED# then
            if not Next (Second)
              or else Second not in 16#80# .. 16#9F#
              or else not Next (Third)
              or else not Is_Continuation (Third)
            then
               Status := Invalid_UTF_8;
               return;
            end if;
         elsif First = 16#F0# then
            if not Next (Second)
              or else Second not in 16#90# .. 16#BF#
              or else not Next (Third)
              or else not Is_Continuation (Third)
              or else not Next (Fourth)
              or else not Is_Continuation (Fourth)
            then
               Status := Invalid_UTF_8;
               return;
            end if;
         elsif First in 16#F1# .. 16#F3# then
            if not Next (Second)
              or else not Is_Continuation (Second)
              or else not Next (Third)
              or else not Is_Continuation (Third)
              or else not Next (Fourth)
              or else not Is_Continuation (Fourth)
            then
               Status := Invalid_UTF_8;
               return;
            end if;
         elsif First = 16#F4# then
            if not Next (Second)
              or else Second not in 16#80# .. 16#8F#
              or else not Next (Third)
              or else not Is_Continuation (Third)
              or else not Next (Fourth)
              or else not Is_Continuation (Fourth)
            then
               Status := Invalid_UTF_8;
               return;
            end if;
         else
            Status := Invalid_UTF_8;
            return;
         end if;
         Count := Count + 1;
      end loop;
      Scalar_Count := Count;
      Status := Valid_UTF_8;
   end Validate_UTF_8;

   procedure Validate_UTF_8 (Input : Octet_Array; Region : Extent; Status : out UTF_8_Status) is
      Scalar_Count : Octet_Count;
   begin
      Validate_UTF_8 (Input, Region, Scalar_Count, Status);
   end Validate_UTF_8;
end Flyology_Wire.Profiles.Tagged_Profile;
