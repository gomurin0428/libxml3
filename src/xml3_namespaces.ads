with XML3_Parser; use XML3_Parser;

package XML3_Namespaces with SPARK_Mode is
   XML_URI : constant String := "http://www.w3.org/XML/1998/namespace";
   XMLNS_URI : constant String := "http://www.w3.org/2000/xmlns/";
   subtype Binding_Id is Natural range 0 .. Max_Nodes + 1;
   Implicit_XML : constant Binding_Id := Max_Nodes + 1;

   type Name_Info is record
      Local_First : Position := 1;
      Prefix_Last : Offset := 0;
      Declaration : Boolean := False;
      Binding     : Binding_Id := 0;
   end record;
   type Name_Array is array (Positive range <>) of Name_Info;

   procedure Resolve
     (Input : String; Nodes : Node_Array; Count : Node_Id;
      Names : out Name_Array; Scratch_A, Scratch_B : in out String;
      Status : out Parse_Status)
     with Global => null, Always_Terminates,
       Pre => Input'First = 1
         and then Input'Length <= Offset'Last
         and then Nodes'First = 1
         and then Nodes'Last in 1 .. Max_Nodes
         and then Count <= Nodes'Last
         and then Names'First = 1
         and then Names'Last = Nodes'Last
         and then Scratch_A'First = 1
         and then Scratch_A'Length = Input'Length
         and then Scratch_B'First = 1
         and then Scratch_B'Length = Input'Length
         and then (for all K in 1 .. Count =>
           Nodes (K).Parent < K
           and then Nodes (K).Name_Last <= Input'Length
           and then Nodes (K).Value_Last <= Input'Length
           and then Nodes (K).Name_First <= Nodes (K).Name_Last + 1
           and then Nodes (K).Value_First <= Nodes (K).Value_Last + 1),
       Post => (if Status = Success then
         (for all K in 1 .. Count =>
           Names (K).Local_First in Nodes (K).Name_First .. Nodes (K).Name_Last + 1
           and Names (K).Prefix_Last in Nodes (K).Name_First - 1 .. Nodes (K).Name_Last
           and (Names (K).Binding <= Count or Names (K).Binding = Implicit_XML)));
end XML3_Namespaces;
