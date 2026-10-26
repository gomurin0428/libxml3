with XML3_DOM.Import;
with XML3_DOM_Constructors;
with XML3_Namespaces;
with XML3_Native_Memory;
with XML3_Parser;
with XML3_Text;

package XML3_DOM.Materialize with SPARK_Mode is
   use type XML3_DOM_Constructors.Construction_Status;

   procedure Build
     (Input : String;
      Nodes : XML3_Parser.Node_Array;
      Count : XML3_Parser.Node_Id;
      Names : XML3_Namespaces.Name_Array;
      Scratch : in out String;
      Source : out State_Access;
      Status : out XML3_DOM_Constructors.Construction_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Input'First = 1
         and then Input'Length <= XML3_Text.Max_Bytes
         and then Nodes'First = 1
         and then Nodes'Last in 1 .. XML3_Parser.Max_Nodes
         and then Count <= Nodes'Last
         and then Names'First = 1 and then Names'Last = Nodes'Last
         and then Scratch'First = 1 and then Scratch'Length = Input'Length
         and then (for all K in 1 .. Count =>
           Nodes (K).Parent < K
           and then Nodes (K).Name_Last <= Input'Length
           and then Nodes (K).Value_Last <= Input'Length
           and then Nodes (K).Name_First <= Nodes (K).Name_Last + 1
           and then Nodes (K).Value_First <= Nodes (K).Value_Last + 1
           and then Names (K).Local_First in
             Nodes (K).Name_First .. Nodes (K).Name_Last + 1
           and then Names (K).Prefix_Last in
             Nodes (K).Name_First - 1 .. Nodes (K).Name_Last
           and then (Names (K).Binding <= Natural (Count)
             or else Names (K).Binding = XML3_Namespaces.Implicit_XML)),
       Post => (if Status = XML3_DOM_Constructors.Created then
           Source /= null
           and then Valid (Source.all) and then Can_Edit (Source.all)
           and then Facades_Present (Source.all)
           and then XML3_DOM.Import.Is_Arena (Source.all)
           and then Projection_Required (Source.all)
         else Source = null);
end XML3_DOM.Materialize;
