with XML3_DOM_Constructors;
with XML3_Serialization;

package body XML3_DOM_Store.Serialization with SPARK_Mode is
   use type System.Address;
   use type XML3_DOM.Node_Ref;
   use type XML3_DOM.Node_Kind;

   procedure Dump
     (S : Store; Document : System.Address; Encoding : String;
      Result : out System.Address; Length : out Natural;
      Status : out Operation_Status)
   is
      N : XML3_DOM.Node_Ref;
   begin
      Result := System.Null_Address;
      Length := 0;
      Status := XML3_DOM_Constructors.Invalid_Argument;
      if S.Current = null or else Document = System.Null_Address then
         return;
      end if;
      N := Find_Node (S, Document);
      if N = XML3_DOM.Null_Node
        or else XML3_DOM.Node (S.Current.all, N).Kind /=
          XML3_DOM.Document_Node
      then
         return;
      end if;
      XML3_Serialization.Render
        (S.Current.all, N, Encoding, Result, Length, Status);
   end Dump;
end XML3_DOM_Store.Serialization;
