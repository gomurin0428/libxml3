with System;
with XML3_Native_Memory;

package XML3_Encoding.Buffers with SPARK_Mode is
   use type System.Address;

   type Conversion_Result is
     (Converted, Invalid_UTF16, Conversion_No_Memory, Conversion_Limit_Exceeded);

   type Input_View is record
      Data : System.Address := System.Null_Address;
      Length : XML3_Text.Byte_Count := 0;
      Info : Encoding_Info;
      Owns_Data : Boolean := False;
   end record;

   procedure Prepare_Input
     (Input : System.Address; Input_Length : XML3_Text.Byte_Count;
      Requested : Encoding_Kind; Result : out Input_View;
      Status : out Conversion_Result)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input /= System.Null_Address and then Requested /= Unsupported,
       Post => Result.Info.Skip <= Input_Length and then Result.Info.Kind /= UTF16
         and then (if Status = Converted then Result.Data /= System.Null_Address
           and then Result.Owns_Data = (Result.Info.Kind /= UTF8)
           and then (if not Result.Owns_Data then
             Result.Length = Input_Length - Result.Info.Skip)
         else Result.Data = System.Null_Address and then Result.Length = 0
           and then not Result.Owns_Data);

   procedure Release_Input (Item : in out Input_View)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Item.Data = System.Null_Address and then Item.Length = 0
         and then not Item.Owns_Data;

   procedure Convert_UTF16
     (Input : System.Address; Input_Length : XML3_Text.Byte_Count;
      Little_Endian : Boolean; Result : out System.Address;
      Length : out XML3_Text.Byte_Count; Status : out Conversion_Result;
      Limit : XML3_Text.Byte_Count := XML3_Text.Max_Bytes)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input /= System.Null_Address,
       Post => (if Status = Converted then Result /= System.Null_Address
                  and then Length <= Limit
                else Result = System.Null_Address and then Length = 0);

   function Classify_Bytes (Name : System.Address) return Encoding_Kind
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Post => (if Name = System.Null_Address then
         Classify_Bytes'Result = Unspecified
         else Classify_Bytes'Result /= Unspecified);
end XML3_Encoding.Buffers;
