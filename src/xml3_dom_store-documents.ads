with XML3_Encoding;
with XML3_Namespaces;
with XML3_Parser;
with XML3_Text;

package XML3_DOM_Store.Documents with SPARK_Mode is
   type Read_Status is
     (Parsed, Malformed, Unsupported, Limit_Exceeded, Arena_Exhausted,
      No_Memory, Internal_Error);

   procedure Read
     (S : in out Store; Input : String; Huge : Boolean;
      Encoding : XML3_Encoding.Encoding_Info;
      Nodes : out XML3_Parser.Node_Array;
      Names : out XML3_Namespaces.Name_Array;
      Scratch_A, Scratch_B : in out String;
      Result : out System.Address; Status : out Read_Status;
      Diagnostic : out XML3_Parser.Diagnostic_Info)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S)
         and then Input'First = 1
         and then Input'Length <= XML3_Text.Max_Bytes
         and then Input'Last in 0 .. XML3_Text.Max_Bytes
         and then Nodes'First = 1
         and then Nodes'Last in 1 .. XML3_Parser.Max_Nodes
         and then Names'First = 1 and then Names'Last = Nodes'Last
         and then Scratch_A'First = 1
         and then Scratch_A'Length = Input'Length
         and then Scratch_B'First = 1
         and then Scratch_B'Length = Input'Length,
       Post => Ready (S)
         and then Diagnostic.Byte_Position in 1 .. Input'Length + 1
         and then (if Status = Parsed then Result /= System.Null_Address
           else Result = System.Null_Address);
end XML3_DOM_Store.Documents;
