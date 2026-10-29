with XML3_Text;
with XML3_Encoding;

package XML3_Parser with SPARK_Mode is
   Max_Nodes : constant := XML3_Text.Max_Bytes / 2;
   Normal_Max_Depth : constant := 256;
   Huge_Max_Depth : constant := 2_048;
   Normal_Max_Name_Length : constant := 50_000;
   Huge_Max_Name_Length : constant := 10_000_000;
   Normal_Max_Value_Length : constant := 10_000_000;
   Huge_Max_Value_Length : constant := 1_000_000_000;
   Max_Depth : constant := Huge_Max_Depth;
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
      Source_Line : Natural range 0 .. 65_535 := 0;
   end record;
   type Node_Array is array (Positive range <>) of Node;
   type Parse_Status is
     (Success, Malformed, Unsupported, Limit_Exceeded, Arena_Exhausted);
   type Diagnostic_Info is record
      Domain   : Natural := 1;
      Code     : Natural := 0;
      Level    : Natural := 3;
      Byte_Position : Position := 1;
      Int1     : Integer := 0;
      Int2     : Integer := 0;
   end record;

   procedure Parse
     (Input  : String;
      Scratch : in out String;
      Nodes  : out Node_Array;
      Count  : out Node_Id;
      Root   : out Node_Id;
      Status : out Parse_Status;
      Huge   : Boolean;
      Diagnostic : out Diagnostic_Info;
      Encoding : XML3_Encoding.Encoding_Info := (others => <>))
     with Global => null, Always_Terminates,
       Pre => Input'First = 1
         and then Input'Length <= XML3_Text.Max_Bytes
         and then Input'Last in 0 .. XML3_Text.Max_Bytes
         and then Scratch'First = 1
         and then Scratch'Length = Input'Length
         and then Nodes'First = 1
         and then Nodes'Last in 1 .. Max_Nodes,
       Post => Scratch'First = 1
         and then Scratch'Length = Input'Length
         and then Nodes'First = 1
         and then Nodes'Last in 1 .. Max_Nodes
         and then Count <= Nodes'Last
         and then Diagnostic.Byte_Position in 1 .. Input'Length + 1
         and then (if Status = Success then Root in 1 .. Count)
         and then (for all K in 1 .. Count =>
           Nodes (K).Parent < K
           and then Nodes (K).Name_Last <= Input'Length
           and then Nodes (K).Value_Last <= Input'Length
           and then Nodes (K).Name_First <= Nodes (K).Name_Last + 1
           and then Nodes (K).Value_First <= Nodes (K).Value_Last + 1);
end XML3_Parser;
