with Flyology_Wire.Compatibility;
with Flyology_Wire.Profiles.Tagged_Profile;

package body Profile_1_Test_Observer is
   package Compatibility renames Flyology_Wire.Compatibility;
   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;

   use type Compatibility.Schema_Relationship;
   use type Flyology_Wire.Byte_Count;
   use type Flyology_Wire.Codecs.Decode_Status;
   use type Interfaces.Unsigned_64;
   use type Profile.Cursor_Status;
   use type Profile.Field_Tag;
   use type Profile.Read_Status;

   Code_Tag : constant Profile.Field_Tag := 1;
   Data_Tag : constant Profile.Field_Tag := 2;

   Maximum_Data_Octets : constant Flyology_Wire.Byte_Count := 4;

   No_Compatible_Writers : constant Compatibility.Schema_Identity_Array (1 .. 0) := [others => <>];

   function Map_Read_Error (Status : Profile.Read_Status) return Flyology_Wire.Codecs.Decode_Status is
   begin
      case Status is
         when Profile.Truncated | Profile.Extent_Outside_Container =>
            return Flyology_Wire.Codecs.Malformed;

         when others                                               =>
            return Flyology_Wire.Codecs.Noncanonical;
      end case;
   end Map_Read_Error;

   procedure Validate
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Status : out Flyology_Wire.Codecs.Decode_Status)
   is
      Relationship  : constant Compatibility.Schema_Relationship :=
        Compatibility.Classify (Observer_Schema, Writer, No_Compatible_Writers);
      Reader        : Profile.Read_Cursor;
      Nested        : Profile.Read_Cursor;
      Previous      : Profile.Tag_Number := Profile.No_Tag;
      Tag           : Profile.Field_Tag;
      Region        : Profile.Extent;
      Cursor_Result : Profile.Cursor_Status;
      Read_Result   : Profile.Read_Status;
      Code          : Interfaces.Unsigned_64;
      Seen_Code     : Boolean := False;
      Seen_Data     : Boolean := False;
   begin
      if Relationship /= Compatibility.Exact then
         Status := Flyology_Wire.Codecs.Incompatible;
         return;
      end if;

      Profile.Initialize (Reader, Input);
      while not Profile.At_End (Reader) loop
         Profile.Read_Field_Header (Input, Reader, Previous, Tag, Region, Read_Result);
         if Read_Result /= Profile.Read then
            Status := Map_Read_Error (Read_Result);
            return;
         elsif Tag = Code_Tag then
            Profile.Initialize (Nested, Input, Region, Cursor_Result);
            if Cursor_Result /= Profile.Cursor_Ready then
               Status := Flyology_Wire.Codecs.Malformed;
               return;
            end if;
            Profile.Read_Unsigned (Input, Nested, Code, Read_Result);
            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then
               Status := Map_Read_Error (Read_Result);
               return;
            elsif Code = 0 then
               Status := Flyology_Wire.Codecs.Invalid_Value;
               return;
            end if;
            Seen_Code := True;
         elsif Tag = Data_Tag then
            if Flyology_Wire.Byte_Count (Region.Length) > Maximum_Data_Octets then
               Status := Flyology_Wire.Codecs.Limit_Exceeded;
               return;
            end if;
            Seen_Data := True;
         else
            Status := Flyology_Wire.Codecs.Noncanonical;
            return;
         end if;
      end loop;

      if not Seen_Code or else not Seen_Data then
         Status := Flyology_Wire.Codecs.Invalid_Value;
      else
         Status := Flyology_Wire.Codecs.Decoded;
      end if;
   end Validate;

   procedure Validate_And_Visit
     (Writer : Flyology_Wire.Codecs.Schema_Identity;
      Input  : Flyology_Wire.Octet_Array;
      Status : out Flyology_Wire.Codecs.Decode_Status)
   is
      Reader       : Profile.Read_Cursor;
      Nested       : Profile.Read_Cursor;
      Previous     : Profile.Tag_Number := Profile.No_Tag;
      Tag          : Profile.Field_Tag;
      Region       : Profile.Extent;
      Read_Result  : Profile.Read_Status;
      Ignore       : Profile.Cursor_Status;
      Code         : Interfaces.Unsigned_64;
      Valid_Status : Flyology_Wire.Codecs.Decode_Status;

      procedure Lend_Data is new Profile.Visit_Extent (Visit_Data);
   begin
      Validate (Writer, Input, Valid_Status);
      if Valid_Status /= Flyology_Wire.Codecs.Decoded then
         Status := Valid_Status;
         return;
      end if;

      Profile.Initialize (Reader, Input);
      while not Profile.At_End (Reader) loop
         Profile.Read_Field_Header (Input, Reader, Previous, Tag, Region, Read_Result);
         if Tag = Code_Tag then
            Profile.Initialize (Nested, Input, Region, Ignore);
            Profile.Read_Unsigned (Input, Nested, Code, Read_Result);
            Visit_Code (Code);
         else
            Lend_Data (Input, Region, Ignore);
         end if;
      end loop;
      Status := Flyology_Wire.Codecs.Decoded;
   end Validate_And_Visit;
end Profile_1_Test_Observer;
