with XML3_Text;

package XML3_Encoding with SPARK_Mode is
   type Encoding_Kind is
     (Unspecified, UTF8, UTF16, UTF16LE, UTF16BE, Unsupported);
   subtype Concrete_Encoding is Encoding_Kind range UTF8 .. UTF16BE;

   type Encoding_Info is record
      Kind : Concrete_Encoding := UTF8;
      Auto_Detected : Boolean := False;
      Explicit : Boolean := False;
      Skip : Natural range 0 .. 3 := 0;
   end record;

   function Classify (Name : String) return Encoding_Kind
     with Global => null;

   function Valid_Name (Name : String) return Boolean
     with Global => null;

   function Declaration_Matches
     (Name : String; Kind : Concrete_Encoding) return Boolean
     with Global => null;

   function Detect
     (Input : String; Requested : Encoding_Kind) return Encoding_Info
     with Global => null,
       Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
         and then Requested /= Unsupported,
       Post => Detect'Result.Skip <= Input'Length
         and then Detect'Result.Kind /= UTF16;

   type Conversion_Status is (Success, Invalid_Encoding, Output_Too_Small);

   --  Measure_Only counts without writing. The same checked conversion is
   --  then used to fill an exactly sized buffer. XML character validity is
   --  checked separately by the parser, as for UTF-8 input.
   procedure Decode_UTF16
     (Input : String;
      Little_Endian : Boolean;
      Output : out String;
      Length : out XML3_Text.Byte_Count;
      Status : out Conversion_Status;
      Error_Position : out Natural;
      Measure_Only : Boolean := False)
     with Global => null, Always_Terminates,
       Pre => Input'First = 1 and then Input'Length <= XML3_Text.Max_Bytes
         and then Output'First = 1
         and then Output'Length <= XML3_Text.Max_Bytes,
       Post => (if not Measure_Only then Length <= Output'Length)
         and then (if Status = Success then Error_Position = 0
                   else Error_Position in 1 .. Input'Length);
end XML3_Encoding;
