with XML3_DOM.Materialize;
with XML3_DOM_Allocation;
with XML3_DOM_Bridge;
with XML3_DOM.Retirement; use XML3_DOM.Retirement;

package body XML3_DOM_Store.Documents with SPARK_Mode is
   use XML3_DOM;
   use type XML3_Parser.Parse_Status;

   procedure Discard_Arena (Source : in out State_Access)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Source /= null and then Valid (Source.all)
         and then Can_Edit (Source.all) and then Facades_Present (Source.all)
         and then XML3_DOM.Import.Is_Arena (Source.all),
       Post => Source = null;

   procedure Discard_Arena (Source : in out State_Access) is
      Count : constant Natural := Node_Count (Source.all);
   begin
      for I in Node_Ref range 1 .. Node_Ref (Count) loop
         if Node (Source.all, I).State = Live then
            Free_Subtree_With_Namespaces (Source.all, I);
         end if;
         pragma Loop_Invariant
           (Valid (Source.all) and then Can_Edit (Source.all)
            and then Facades_Present (Source.all)
            and then Node_Count (Source.all) = Count);
         pragma Loop_Invariant
           (for all J in Node_Ref range 1 .. I =>
              Node (Source.all, J).State /= Live);
      end loop;
      XML3_DOM_Bridge.Synchronize (Source.all);
      XML3_DOM_Allocation.Free_State (Source);
   end Discard_Arena;

   procedure Read
     (S : in out Store; Input : String; Huge : Boolean;
      Encoding : XML3_Encoding.Encoding_Info;
      Nodes : out XML3_Parser.Node_Array;
      Names : out XML3_Namespaces.Name_Array;
      Scratch_A, Scratch_B : in out String;
      Result : out System.Address; Status : out Read_Status;
      Diagnostic : out XML3_Parser.Diagnostic_Info)
   is
      Count, Root : XML3_Parser.Node_Id;
      Parsed_Status : XML3_Parser.Parse_Status;
      Namespace_Diagnostic : XML3_Parser.Diagnostic_Info;
      Source : State_Access;
      Built : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Internal_Error;
      Names := (others => <>);
      XML3_Parser.Parse
        (Input, Scratch_A, Nodes, Count, Root, Parsed_Status, Huge,
         Diagnostic, Encoding);
      if Parsed_Status = XML3_Parser.Success then
         XML3_Namespaces.Resolve
           (Input, Nodes, Count, Names, Scratch_A, Scratch_B, Parsed_Status,
            Namespace_Diagnostic);
         if Parsed_Status /= XML3_Parser.Success
           or else Namespace_Diagnostic.Code /= 0
         then
            Diagnostic := Namespace_Diagnostic;
         end if;
      end if;
      case Parsed_Status is
         when XML3_Parser.Malformed => Status := Malformed;
         when XML3_Parser.Unsupported => Status := Unsupported;
         when XML3_Parser.Limit_Exceeded => Status := Limit_Exceeded;
         when XML3_Parser.Arena_Exhausted => Status := Arena_Exhausted;
         when XML3_Parser.Success => null;
      end case;
      if Parsed_Status /= XML3_Parser.Success then
         return;
      end if;

      XML3_DOM.Materialize.Build
        (Input, Nodes, Count, Names, Scratch_A, Source, Built);
      if Built = XML3_DOM_Constructors.Created then
         Adopt_Arena (S, Source, Result, Built);
         if Source /= null then
            Discard_Arena (Source);
         end if;
      end if;
      case Built is
         when XML3_DOM_Constructors.Created => Status := Parsed;
         when XML3_DOM_Constructors.No_Memory => Status := No_Memory;
         when XML3_DOM_Constructors.Limit_Exceeded => Status := Limit_Exceeded;
         when others => Status := Internal_Error;
      end case;
   end Read;
end XML3_DOM_Store.Documents;
