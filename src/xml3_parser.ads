with XML3_Text;

package XML3_Parser with SPARK_Mode is
   Max_Nodes : constant := 2_048;
   Max_Depth : constant := 64;
   subtype Node_Id is Natural range 0 .. Max_Nodes;
   subtype Position is Positive range 1 .. XML3_Text.Max_Bytes + 1;
   subtype Offset is XML3_Text.Byte_Count;
   type Node_Kind is (Element_Node, Attribute_Node, Text_Node,
                     CData_Node, Comment_Node, PI_Node);
   type Node is record
      Kind        : Node_Kind := Element_Node;
      Parent      : Node_Id := 0;
      Name_First  : Position := 1;
      Name_Last   : Offset := 0;
      Value_First : Position := 1;
      Value_Last  : Offset := 0;
   end record;
   type Node_Array is array (Positive range 1 .. Max_Nodes) of Node;
   type Parse_Status is (Success, Malformed, Unsupported, Limit_Exceeded);

   procedure Parse
     (Input  : String;
      Nodes  : out Node_Array;
      Count  : out Node_Id;
      Root   : out Node_Id;
      Status : out Parse_Status)
     with Global => null, Always_Terminates,
       Pre => Input'First = 1 and Input'Length <= XML3_Text.Max_Bytes,
       Post => (if Status = Success then Root in 1 .. Count)
         and (for all K in 1 .. Count =>
           Nodes (K).Parent < K
           and Nodes (K).Name_Last <= Input'Length
           and Nodes (K).Value_Last <= Input'Length
           and Nodes (K).Name_First <= Nodes (K).Name_Last + 1
           and Nodes (K).Value_First <= Nodes (K).Value_Last + 1);
end XML3_Parser;
