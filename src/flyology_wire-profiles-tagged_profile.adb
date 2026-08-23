package body Flyology_Wire.Profiles.Tagged_Profile is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Octet;
   use type Octet_Count;
   use type Sizes.Arithmetic_Status;

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
end Flyology_Wire.Profiles.Tagged_Profile;
