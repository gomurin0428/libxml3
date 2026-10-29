with XML3_DOM_Constructors;
with XML3_Namespaces;
with XML3_Text.Buffers;

package body XML3_DOM_Store.Queries with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

   function Line_At_Node
     (S : XML3_DOM.State; N : Node_Ref; Remaining : Natural) return Integer
     with Global => null,
       Pre => Valid (S),
       Post => Line_At_Node'Result in -1 .. 65_535,
       Subprogram_Variant => (Decreases => Remaining)
   is
      Item : Node_View;
      Target : Node_Ref := Null_Node;
      Result : Integer := -1;
   begin
      if Remaining = 0 or else N not in 1 .. Node_Ref (Node_Count (S)) then
         return -1;
      end if;
      Item := Node (S, N);
      if Item.State /= Live then
         return -1;
      end if;
      if Item.Kind in Element_Node | Text_Node | Comment_Node |
        Processing_Instruction_Node
      then
         if Item.Source_Line = 65_535 then
            if Item.Kind = Element_Node and then Item.First_Child /= Null_Node then
               Target := Item.First_Child;
            elsif Item.Next /= Null_Node then
               Target := Item.Next;
            else
               Target := Item.Previous;
            end if;
            Result := Line_At_Node (S, Target, Remaining - 1);
         end if;
         return (if Result = -1 or else Result = 65_535
                 then Item.Source_Line else Result);
      end if;
      if Item.Previous in 1 .. Node_Ref (Node_Count (S))
        and then Node (S, Item.Previous).Kind in
          Element_Node | Text_Node | Comment_Node | Processing_Instruction_Node
      then
         return Line_At_Node (S, Item.Previous, Remaining - 1);
      elsif Item.Parent in 1 .. Node_Ref (Node_Count (S))
        and then Node (S, Item.Parent).Kind = Element_Node
      then
         return Line_At_Node (S, Item.Parent, Remaining - 1);
      end if;
      return -1;
   end Line_At_Node;

   procedure Get_Line_Number
     (S : Store; Facade : System.Address; Result : out Integer)
   is
      N : constant Node_Ref := Find_Node (S, Facade);
   begin
      Result := -1;
      if N /= Null_Node then
         Result := Line_At_Node (S.Current.all, N, 5);
      end if;
   end Get_Line_Number;

   function Registered_Document (S : Store; Document : System.Address)
     return Boolean
     with Global => null,
       Pre => S.Current = null
         or else
           (XML3_DOM.Valid (S.Current.all)
            and then XML3_DOM.Can_Edit (S.Current.all)
            and then not XML3_DOM.Projection_Required (S.Current.all)
            and then XML3_DOM.Facades_Present (S.Current.all))
   is
      N : constant Node_Ref := Find_Registered_Node (S, Document);
   begin
      return Document = System.Null_Address
        or else (N /= Null_Node
          and then Node (S.Current.all, N).Kind = Document_Node);
   end Registered_Document;

   function Encoding_Status (Status : XML3_Text.Buffers.Escape_Status)
     return Operation_Status
   is (case Status is
          when XML3_Text.Buffers.Escaped => Created,
          when XML3_Text.Buffers.Invalid_Text => Invalid_Argument,
          when XML3_Text.Buffers.Escape_No_Memory => No_Memory,
          when XML3_Text.Buffers.Escape_Limit_Exceeded => Limit_Exceeded);

   procedure Encode_Entities
     (S : Store; Document : System.Address; Input : String;
      Result : out System.Address; Status : out Operation_Status)
   is
      Escaping : XML3_Text.Buffers.Escape_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if not Registered_Document (S, Document) then
         return;
      end if;
      XML3_Text.Buffers.Escape_Special
        (Input, Result, Escaping, Non_ASCII => True, Quotes => False);
      Status := Encoding_Status (Escaping);
   end Encode_Entities;

   procedure Find_Matching_Property
     (S : Store; Element, Attribute : System.Address;
      Result : out System.Address; Status : out Operation_Status;
      Name : System.Address := System.Null_Address; Name_Length : Natural := 0;
      Exclude_Source : Boolean := False)
   is
      E : constant Node_Ref := Find_Node (S, Element);
      N : constant Node_Ref := Find_Node (S, Attribute);
      P : Node_Ref;
      Source, Candidate : Node_View;
      Source_Ns, Candidate_Ns : Namespace_View;
      Matches : Boolean;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if E = Null_Node or else N = Null_Node
        or else Node (S.Current.all, E).Kind /= Element_Node
        or else Node (S.Current.all, N).Kind /= Attribute_Node
      then
         return;
      end if;
      Source := Node (S.Current.all, N);
      if Name /= System.Null_Address then
         Source.Name := Name;
         Source.Name_Length := Name_Length;
      end if;
      if Source.Name = System.Null_Address then
         return;
      end if;
      if Source.Namespace /= Null_Namespace then
         if Source.Namespace > Namespace_Ref (Namespace_Count (S.Current.all))
           or else Namespace (S.Current.all, Source.Namespace).State /= Live
         then
            return;
         end if;
         Source_Ns := Namespace (S.Current.all, Source.Namespace);
         if Source_Ns.Href = System.Null_Address then
            return;
         end if;
      end if;
      P := Node (S.Current.all, E).First_Prop;
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when P = Null_Node;
         if P > Node_Ref (Node_Count (S.Current.all))
           or else Node (S.Current.all, P).State /= Live
         then
            Status := Internal_Error;
            return;
         end if;
         Candidate := Node (S.Current.all, P);
         if Candidate.Kind /= Attribute_Node or else Candidate.Parent /= E
           or else Candidate.Name = System.Null_Address
         then
            Status := Internal_Error;
            return;
         end if;
         Matches := False;
         if Candidate.Name_Length = Source.Name_Length
           and then Native.Equal_Bytes
             (Candidate.Name, Source.Name, Source.Name_Length)
         then
            if Source.Namespace = Null_Namespace then
               Matches := Candidate.Namespace = Null_Namespace;
            elsif Candidate.Namespace /= Null_Namespace
              and then Candidate.Namespace <=
                Namespace_Ref (Namespace_Count (S.Current.all))
              and then Namespace (S.Current.all, Candidate.Namespace).State = Live
            then
               Candidate_Ns := Namespace (S.Current.all, Candidate.Namespace);
               Matches := Candidate_Ns.Href /= System.Null_Address
                 and then Candidate_Ns.Href_Length = Source_Ns.Href_Length
                 and then Native.Equal_Bytes
                   (Candidate_Ns.Href, Source_Ns.Href, Source_Ns.Href_Length);
            end if;
         end if;
         if Matches and then (not Exclude_Source or else P /= N) then
            Result := Candidate.Facade;
            Status := Created;
            return;
         end if;
         P := Candidate.Next;
      end loop;
      Status := (if P = Null_Node then Created else Internal_Error);
   end Find_Matching_Property;

   procedure Test_Node
     (S : Store; Facade : System.Address; Mode : Node_Test_Kind;
      Result : out Boolean; Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Node (S, Facade);
   begin
      Result := False;
      Status := Invalid_Argument;
      if N = Null_Node then
         return;
      end if;
      declare
         V : constant Node_View := Node (S.Current.all, N);
      begin
         Status := Created;
         if Mode = Text_Test then
            Result := V.Kind = Text_Node;
            return;
         elsif V.Kind not in Text_Node | CData_Node then
            return;
         end if;
         if V.Content_Length > 0 then
            if V.Content = System.Null_Address then
               Status := Internal_Error;
               return;
            end if;
            for I in 0 .. V.Content_Length - 1 loop
               if not XML3_Text.XML_Blank
                 (Character'Pos (Native.Byte_At (V.Content, I)))
               then
                  return;
               end if;
            end loop;
         end if;
         Result := True;
      end;
   end Test_Node;

   function Node_In_Range (S : Store; N : Node_Ref) return Boolean is
     (S.Current /= null
      and then N /= Null_Node
      and then N <= Node_Ref (Node_Count (S.Current.all)))
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all),
       Post => (if Node_In_Range'Result then
         S.Current /= null
         and then N in 1 .. Node_Ref (Capacity_Of (S.Current.all)));

   function Namespace_In_Range
     (S : Store; N : Namespace_Ref) return Boolean is
     (S.Current /= null
      and then N /= Null_Namespace
      and then N <= Namespace_Ref (Namespace_Count (S.Current.all)))
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all),
       Post => (if Namespace_In_Range'Result then
         S.Current /= null
         and then N in 1 .. Namespace_Ref (Capacity_Of (S.Current.all)));

   function Live_Node (S : Store; N : Node_Ref) return Boolean is
     (Node_In_Range (S, N)
      and then Node (S.Current.all, N).State = XML3_DOM.Live)
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all),
       Post => (if Live_Node'Result then
         N in 1 .. Node_Ref (Capacity_Of (S.Current.all)));

   function Live_Namespace (S : Store; N : Namespace_Ref) return Boolean is
     (Namespace_In_Range (S, N)
      and then Namespace (S.Current.all, N).State = XML3_DOM.Live)
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all),
       Post => (if Live_Namespace'Result then
         N in 1 .. Namespace_Ref (Capacity_Of (S.Current.all)));

   function Equal_Bytes
     (Base : System.Address; Length : Natural; Value : String)
      return Boolean
   is
   begin
      if Length /= Value'Length then
         return False;
      elsif Length = 0 then
         return True;
      elsif Base = System.Null_Address then
         return False;
      end if;
      for I in 0 .. Length - 1 loop
         if Native.Byte_At (Base, I) /= Value (Value'First + I) then
            return False;
         end if;
      end loop;
      return True;
   end Equal_Bytes;

   function Equal_Address_Bytes
     (Left : System.Address; Left_Length : Natural;
      Right : System.Address; Right_Length : Natural) return Boolean
   is
   begin
      if Left_Length /= Right_Length then
         return False;
      elsif Left_Length = 0 then
         return (Left = System.Null_Address) =
           (Right = System.Null_Address);
      elsif Left = System.Null_Address
        or else Right = System.Null_Address
      then
         return False;
      end if;
      for I in 0 .. Left_Length - 1 loop
         if Native.Byte_At (Left, I) /= Native.Byte_At (Right, I) then
            return False;
         end if;
      end loop;
      return True;
   end Equal_Address_Bytes;

   function Same_Prefix
     (Left : Namespace_View; Right : Namespace_View) return Boolean is
     (Left.Prefix = Right.Prefix
        or else
          (Left.Prefix /= System.Null_Address
           and then Right.Prefix /= System.Null_Address
           and then Equal_Address_Bytes
             (Left.Prefix, Left.Prefix_Length,
              Right.Prefix, Right.Prefix_Length)));

   function Namespace_Matches
     (Candidate : Namespace_View; Mode : Namespace_Query_Kind;
      Has_Value : Boolean; Value : String) return Boolean
   is
   begin
      if Mode = Prefix_Search then
         if Candidate.Href = System.Null_Address then
            return False;
         end if;
         if not Has_Value then
            return Candidate.Prefix = System.Null_Address;
         end if;
         return Candidate.Prefix /= System.Null_Address
           and then Equal_Bytes
             (Candidate.Prefix, Candidate.Prefix_Length, Value);
      end if;
      return (if Has_Value then
                Candidate.Href /= System.Null_Address
                and then Equal_Bytes
                  (Candidate.Href, Candidate.Href_Length, Value)
              else Candidate.Href = System.Null_Address);
   end Namespace_Matches;

   function Implicit_Query
     (Mode : Namespace_Query_Kind; Has_Value : Boolean;
      Value : String) return Boolean is
   begin
      return Has_Value
        and then
          ((Mode = Prefix_Search and then Value = "xml")
           or else
             (Mode = Href_Search and then Value = XML3_Namespaces.XML_URI));
   end Implicit_Query;

   function Find_Implicit
     (S : Store; N : Node_Ref) return Namespace_Ref
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all)
       and then Live_Node (S, N),
       Post => (if Find_Implicit'Result /= Null_Namespace then
         Namespace_In_Range (S, Find_Implicit'Result))
   is
      D : Node_Ref := Null_Node;
      B : Owner_Ref := Null_Owner;
      Candidate : Namespace_View;
   begin
      if not Live_Node (S, N) then
         return Null_Namespace;
      end if;
      D := Node (S.Current.all, N).Document;
      if not Node_In_Range (S, D) then
         return Null_Namespace;
      end if;
      if Node (S.Current.all, D).State /= Live
        and then Node (S.Current.all, D).State /= Tombstone
      then
         return Null_Namespace;
      end if;
      B := Node (S.Current.all, D).Owner;
      if B = Null_Owner
        or else B > Owner_Ref (Owner_Count (S.Current.all))
      then
         return Null_Namespace;
      end if;
      for I in Namespace_Ref range
        1 .. Namespace_Ref (Namespace_Count (S.Current.all))
      loop
         Candidate := Namespace (S.Current.all, I);
         if Candidate.State = Live
           and then not Candidate.Attached
           and then Candidate.Owner = B
           and then Candidate.Prefix /= System.Null_Address
           and then Equal_Bytes (Candidate.Prefix, Candidate.Prefix_Length, "xml")
           and then Candidate.Href /= System.Null_Address
           and then Equal_Bytes
             (Candidate.Href, Candidate.Href_Length, XML3_Namespaces.XML_URI)
         then
            return I;
         end if;
      end loop;
      return Null_Namespace;
   end Find_Implicit;

   procedure Prefix_Resolved
     (S : Store; Original : Node_Ref; Candidate : Namespace_View;
      Resolved : out Namespace_Ref; Status : out Operation_Status;
      Declarations_Only : Boolean := False)
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all)
       and then Live_Node (S, Original)
   is
      Current : Node_Ref;
      Ns : Namespace_Ref;
      Item : Namespace_View;
   begin
      Resolved := Null_Namespace;
      Status := Created;
      Current :=
        (if Node (S.Current.all, Original).Kind = Attribute_Node
         then Node (S.Current.all, Original).Parent
         else Original);
      for Outer in 1 .. Node_Count (S.Current.all) loop
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            return;
         end if;
         if Node (S.Current.all, Current).Kind = Element_Node then
            Ns := Node (S.Current.all, Current).First_Namespace;
            for Inner in 1 .. Namespace_Count (S.Current.all) loop
               exit when Ns = Null_Namespace;
               if not Live_Namespace (S, Ns) then
                  Status := Internal_Error;
                  return;
               end if;
               Item := Namespace (S.Current.all, Ns);
               if Same_Prefix (Item, Candidate) then
                  Resolved := Ns;
                  return;
               end if;
               Ns := Item.Next;
            end loop;
            if Ns /= Null_Namespace then
               Status := Internal_Error;
               return;
            end if;
            if Current /= Original and then not Declarations_Only then
               Ns := Node (S.Current.all, Current).Namespace;
               if Ns /= Null_Namespace then
                  if not Live_Namespace (S, Ns) then
                     Status := Internal_Error;
                     return;
                  end if;
                  Item := Namespace (S.Current.all, Ns);
                  if Item.Href /= System.Null_Address
                    and then Same_Prefix (Item, Candidate)
                  then
                     Resolved := Ns;
                     return;
                  end if;
               end if;
            end if;
         end if;
         Current := Node (S.Current.all, Current).Parent;
      end loop;
      if Current /= Null_Node then
         Status := Internal_Error;
      end if;
   end Prefix_Resolved;

   procedure Collect_Namespaces
     (S : Store; Original : Node_Ref; Buffer : System.Address;
      Capacity : Natural; Count : out Natural; Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => S.Current /= null
         and then XML3_DOM.Valid (S.Current.all)
         and then Live_Node (S, Original)
         and then (Buffer = System.Null_Address or else
           Native.Byte_Count (Capacity) <= Native.Byte_Count'Last / Native.Address_Bytes),
       Post => Count <= Capacity
   is
      Current : Node_Ref := Original;
      Ns, Resolved : Namespace_Ref;
      Item : Namespace_View;
   begin
      Count := 0;
      Status := Created;
      for Outer in 1 .. Node_Count (S.Current.all) loop
         pragma Loop_Invariant (Count <= Capacity);
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            return;
         end if;
         if Node (S.Current.all, Current).Kind = Element_Node then
            Ns := Node (S.Current.all, Current).First_Namespace;
            for Inner in 1 .. Namespace_Count (S.Current.all) loop
               pragma Loop_Invariant (Count <= Capacity);
               exit when Ns = Null_Namespace;
               if not Live_Namespace (S, Ns) then
                  Status := Internal_Error;
                  return;
               end if;
               Item := Namespace (S.Current.all, Ns);
               Prefix_Resolved
                 (S, Original, Item, Resolved, Status, Declarations_Only => True);
               if Status /= Created then
                  return;
               end if;
               if Resolved = Ns then
                  if Count = Capacity then
                     Status := Limit_Exceeded;
                     return;
                  end if;
                  if Buffer /= System.Null_Address then
                     Native.Write_Address (Buffer, Count, Item.Facade);
                  end if;
                  Count := Count + 1;
               end if;
               Ns := Item.Next;
            end loop;
            if Ns /= Null_Namespace then
               Status := Internal_Error;
               return;
            end if;
         end if;
         Current := Node (S.Current.all, Current).Parent;
      end loop;
      if Current /= Null_Node then
         Status := Internal_Error;
      end if;
   end Collect_Namespaces;

   procedure Get_Namespace_List
     (S : Store; Facade : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      Original : constant Node_Ref := Find_Node (S, Facade);
      Count, Written : Natural;
      Buffer : System.Address := System.Null_Address;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if S.Current = null or else Original = Null_Node then
         return;
      end if;
      Collect_Namespaces
        (S, Original, System.Null_Address, Natural'Last - 1, Count, Status);
      if Status /= Created or else Count = 0 then
         return;
      end if;
      if Native.Byte_Count (Count) >= Native.Byte_Count'Last / Native.Address_Bytes then
         Status := Limit_Exceeded;
         return;
      end if;
      Native.Allocate
        ((Native.Byte_Count (Count) + 1) * Native.Address_Bytes, Buffer);
      if Buffer = System.Null_Address then
         Status := No_Memory;
         return;
      end if;
      Collect_Namespaces (S, Original, Buffer, Count, Written, Status);
      if Status /= Created or else Written /= Count then
         Native.Free (Buffer);
         if Status = Created then
            Status := Internal_Error;
         end if;
         return;
      end if;
      Native.Write_Address (Buffer, Count, System.Null_Address);
      Result := Buffer;
   end Get_Namespace_List;

   procedure Is_In_Scope
     (S : Store; Original : Node_Ref; Candidate : Namespace_View;
      Candidate_Id : Namespace_Ref; Matches : out Boolean;
      Status : out Operation_Status)
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all)
       and then Live_Node (S, Original)
       and then Live_Namespace (S, Candidate_Id)
   is
      Resolved : Namespace_Ref;
   begin
      Matches := False;
      Prefix_Resolved (S, Original, Candidate, Resolved, Status);
      if Status = Created then
         Matches := Resolved = Candidate_Id;
      end if;
   end Is_In_Scope;

   procedure Candidate_Allowed
     (S : Store; Original : Node_Ref; Is_Attribute : Boolean;
      Mode : Namespace_Query_Kind; Has_Value : Boolean; Value : String;
      Candidate : Namespace_View; Candidate_Id : Namespace_Ref;
      Allowed : out Boolean; Status : out Operation_Status)
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all)
       and then Live_Node (S, Original)
       and then Live_Namespace (S, Candidate_Id)
   is
      Matches : Boolean;
   begin
      Allowed := False;
      Status := Created;
      if not Namespace_Matches (Candidate, Mode, Has_Value, Value) then
         return;
      end if;
      if Mode = Href_Search then
         if Is_Attribute and then Candidate.Prefix = System.Null_Address then
            return;
         end if;
         Is_In_Scope
           (S, Original, Candidate, Candidate_Id, Matches, Status);
         if Status /= Created then
            return;
         end if;
         Allowed := Matches;
      else
         Allowed := True;
      end if;
   end Candidate_Allowed;

   procedure Select_Element
     (S : Store; Facade : System.Address; Mode : Element_Query_Kind;
      Result : out System.Address; Count : out Natural;
      Status : out Operation_Status)
   is
      Start : Node_Ref;
      Current : Node_Ref;
      N : Node_View;
      Backward : constant Boolean := Mode in Last_Element | Previous_Element;
   begin
      Result := System.Null_Address;
      Count := 0;
      Status := Invalid_Argument;
      if S.Current = null then
         return;
      end if;
      Start := Find_Node (S, Facade);
      if Start = Null_Node then
         return;
      end if;
      N := Node (S.Current.all, Start);
      if Mode = Document_Root and then N.Kind /= Document_Node then
         return;
      end if;
      if (Mode = Last_Element and then N.Kind not in Element_Node | Document_Node)
        or else (Mode = Previous_Element
                 and then N.Kind in Document_Node | Attribute_Node)
      then
         Status := Created;
         return;
      end if;
      Current := (case Mode is
         when Next_Element => N.Next,
         when Previous_Element => N.Previous,
         when Last_Element | Last_Child_Node => N.Last_Child,
         when others => N.First_Child);
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            Count := 0;
            return;
         end if;
         N := Node (S.Current.all, Current);
         if Mode = Last_Child_Node or else N.Kind = Element_Node then
            if Mode = Element_Count then
               if Count = Natural'Last then
                  Status := Limit_Exceeded;
                  Count := 0;
                  return;
               end if;
               Count := Count + 1;
            else
               Result := N.Facade;
               Status := Created;
               return;
            end if;
         end if;
         Current := (if Backward then N.Previous else N.Next);
      end loop;
      if Current /= Null_Node then
         Status := Internal_Error;
         Count := 0;
         return;
      end if;
      Status := Created;
   end Select_Element;

   procedure Find_Property
     (S : Store; Element : System.Address; Name : String;
      Filter : Property_Filter; Href : String;
      Result : out System.Address; Status : out Operation_Status)
   is
      E : Node_Ref;
      P : Node_Ref;
      A : Node_View;
      Ns : Namespace_View;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if S.Current = null then
         return;
      end if;
      E := Find_Node (S, Element);
      if E = Null_Node or else Node (S.Current.all, E).Kind /= Element_Node then
         return;
      end if;
      P := Node (S.Current.all, E).First_Prop;
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when P = Null_Node;
         if not Live_Node (S, P)
           or else Node (S.Current.all, P).Kind /= Attribute_Node
         then
            Status := Internal_Error;
            return;
         end if;
         A := Node (S.Current.all, P);
         if Equal_Bytes (A.Name, A.Name_Length, Name) then
            if Filter = Any_Namespace then
               Result := A.Facade;
               Status := Created;
               return;
            elsif Filter = No_Namespace then
               if A.Namespace = Null_Namespace then
                  Result := A.Facade;
                  Status := Created;
                  return;
               end if;
            elsif A.Namespace /= Null_Namespace then
               if not Live_Namespace (S, A.Namespace) then
                  Status := Internal_Error;
                  return;
               end if;
               Ns := Namespace (S.Current.all, A.Namespace);
               if Ns.Href /= System.Null_Address
                 and then Equal_Bytes (Ns.Href, Ns.Href_Length, Href)
               then
                  Result := A.Facade;
                  Status := Created;
                  return;
               end if;
            end if;
         end if;
         P := A.Next;
      end loop;
      if P /= Null_Node then
         Status := Internal_Error;
         return;
      end if;
      Status := Created;
   end Find_Property;

   procedure Search_Namespace
     (S : Store; Facade : System.Address; Mode : Namespace_Query_Kind;
      Has_Value : Boolean; Value : String;
      Result : out System.Address; Status : out Operation_Status)
   is
      Original : Node_Ref;
      Current : Node_Ref;
      Ns : Namespace_Ref;
      Candidate : Namespace_View;
      Original_View : Node_View;
      Allowed : Boolean;
      Candidate_Status : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if S.Current = null then
         return;
      end if;
      Original := Find_Node (S, Facade);
      if Original = Null_Node then
         return;
      end if;
      Original_View := Node (S.Current.all, Original);
      if Implicit_Query (Mode, Has_Value, Value) then
         Ns := Find_Implicit (S, Original);
         if Ns /= Null_Namespace then
            Result := Namespace (S.Current.all, Ns).Facade;
            Status := Created;
            return;
         end if;
      end if;
      Current :=
        (if Original_View.Kind = Attribute_Node
         then Original_View.Parent
         else Original);
      for Outer in 1 .. Node_Count (S.Current.all) loop
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            return;
         end if;
         if Node (S.Current.all, Current).Kind = Element_Node then
            Ns := Node (S.Current.all, Current).First_Namespace;
            for Inner in 1 .. Namespace_Count (S.Current.all) loop
               exit when Ns = Null_Namespace;
               if not Live_Namespace (S, Ns) then
                  Status := Internal_Error;
                  return;
               end if;
               Candidate := Namespace (S.Current.all, Ns);
               Candidate_Allowed
                 (S, Original, Original_View.Kind = Attribute_Node,
                  Mode, Has_Value, Value, Candidate, Ns,
                  Allowed, Candidate_Status);
               if Candidate_Status /= Created then
                  Status := Candidate_Status;
                  return;
               elsif Allowed then
                  Result := Candidate.Facade;
                  Status := Created;
                  return;
               end if;
               Ns := Candidate.Next;
            end loop;
            if Ns /= Null_Namespace then
               Status := Internal_Error;
               return;
            end if;
            if Current /= Original then
               Ns := Node (S.Current.all, Current).Namespace;
               if Ns /= Null_Namespace then
                  if not Live_Namespace (S, Ns) then
                     Status := Internal_Error;
                     return;
                  end if;
                  Candidate := Namespace (S.Current.all, Ns);
                  if Candidate.Href /= System.Null_Address then
                     Candidate_Allowed
                       (S, Original, Original_View.Kind = Attribute_Node,
                        Mode, Has_Value, Value, Candidate, Ns,
                        Allowed, Candidate_Status);
                     if Candidate_Status /= Created then
                        Status := Candidate_Status;
                        return;
                     elsif Allowed then
                        Result := Candidate.Facade;
                        Status := Created;
                        return;
                     end if;
                  end if;
               end if;
            end if;
         end if;
         Current := Node (S.Current.all, Current).Parent;
      end loop;
      if Current /= Null_Node then
         Status := Internal_Error;
         return;
      end if;
      Status := Created;
   end Search_Namespace;

   procedure Lookup_Namespace
     (S : in out Store; Facade : System.Address; Mode : Namespace_Query_Kind;
      Has_Value : Boolean; Value : String;
      Result : out System.Address; Status : out Operation_Status)
   is
      Current : Node_Ref;
      Item : Node_View;
   begin
      Search_Namespace (S, Facade, Mode, Has_Value, Value, Result, Status);
      if Status /= Created or else Result /= System.Null_Address
        or else not Implicit_Query (Mode, Has_Value, Value)
      then
         return;
      end if;
      Current := Find_Node (S, Facade);
      if Current = Null_Node
        or else Node (S.Current.all, Current).Document /= Null_Node
      then
         return;
      end if;
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            return;
         end if;
         Item := Node (S.Current.all, Current);
         if Item.Kind = Element_Node then
            Create_Namespace
              (S, Item.Facade, XML3_Namespaces.XML_URI, "xml", True, True,
               Result, Status);
            if Status /= Created then
               Result := System.Null_Address;
            end if;
            return;
         end if;
         Current := Item.Parent;
      end loop;
      if Current /= Null_Node then
         Status := Internal_Error;
      end if;
   end Lookup_Namespace;

   procedure Next_Depth_First
     (S : Store; Root, Current : Node_Ref;
      Next : out Node_Ref; Valid : out Boolean)
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all)
       and then Live_Node (S, Root)
       and then Live_Node (S, Current)
   is
      Parent : Node_Ref;
   begin
      Next := Null_Node;
      Valid := False;
      if not Live_Node (S, Root) or else not Live_Node (S, Current) then
         return;
      end if;
      Next := Node (S.Current.all, Current).First_Child;
      if Next /= Null_Node then
         if not Live_Node (S, Next) then
            Next := Null_Node;
            return;
         end if;
         Valid := True;
         return;
      end if;
      Parent := Current;
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when Parent = Root;
         if not Live_Node (S, Parent) then
            Next := Null_Node;
            return;
         end if;
         Next := Node (S.Current.all, Parent).Next;
         if Next /= Null_Node then
            if not Live_Node (S, Next) then
               Next := Null_Node;
               return;
            end if;
            Valid := True;
            return;
         end if;
         Parent := Node (S.Current.all, Parent).Parent;
      end loop;
      if Parent /= Root then
         Next := Null_Node;
         return;
      end if;
      Valid := True;
   end Next_Depth_First;

   function Is_Text_Content (Kind : Node_Kind) return Boolean is
     (Kind = Text_Node or else Kind = CData_Node);

   procedure Measure_Content
     (S : Store; Root : Node_Ref; Total : out Natural;
      Status : out Operation_Status)
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all)
       and then Live_Node (S, Root)
   is
      Current : Node_Ref;
      Next : Node_Ref;
      Good : Boolean;
      Item : Node_View;
   begin
      Total := 0;
      Status := Created;
      Current := Node (S.Current.all, Root).First_Child;
      if Current /= Null_Node and then not Live_Node (S, Current) then
         Status := Internal_Error;
         return;
      end if;
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            return;
         end if;
         Item := Node (S.Current.all, Current);
         if Is_Text_Content (Item.Kind) then
            if Item.Content_Length > 0
              and then Item.Content = System.Null_Address
            then
               Status := Internal_Error;
               return;
            end if;
            if Total > Natural'Last - Item.Content_Length then
               Status := Limit_Exceeded;
               return;
            end if;
            Total := Total + Item.Content_Length;
         end if;
         Next_Depth_First (S, Root, Current, Next, Good);
         if not Good then
            Status := Internal_Error;
            return;
         end if;
         Current := Next;
      end loop;
      if Current /= Null_Node then
         Status := Internal_Error;
      end if;
   end Measure_Content;

   procedure Copy_Content
     (S : Store; Root : Node_Ref; Base : System.Address;
      Total : Natural; Status : out Operation_Status)
     with Pre => S.Current /= null
       and then XML3_DOM.Valid (S.Current.all)
       and then Live_Node (S, Root)
       and then Base /= System.Null_Address
   is
      Current : Node_Ref;
      Next : Node_Ref;
      Good : Boolean;
      Cursor : Natural := 0;
      Item : Node_View;
      Target : System.Address;
   begin
      Status := Created;
      Current := Node (S.Current.all, Root).First_Child;
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            return;
         end if;
         Item := Node (S.Current.all, Current);
         if Is_Text_Content (Item.Kind) then
            if Item.Content_Length > 0
              and then Item.Content = System.Null_Address
            then
               Status := Internal_Error;
               return;
            end if;
            if Cursor > Total
              or else Item.Content_Length > Total - Cursor
            then
               Status := Internal_Error;
               return;
            end if;
            Target := Native.Offset (Base, Native.Byte_Count (Cursor));
            if Target = System.Null_Address then
               Status := Internal_Error;
               return;
            end if;
            Native.Copy_Bytes
              (Item.Content, Target, Item.Content_Length);
            Cursor := Cursor + Item.Content_Length;
         end if;
         Next_Depth_First (S, Root, Current, Next, Good);
         if not Good then
            Status := Internal_Error;
            return;
         end if;
         Current := Next;
      end loop;
      if Current /= Null_Node or else Cursor /= Total then
         Status := Internal_Error;
      end if;
   end Copy_Content;

   procedure Get_Inherited_XML_Property
     (S : Store; Facade : System.Address; Mode : XML_Property_Kind;
      Result : out System.Address; Space : out Space_Policy;
      Status : out Operation_Status)
   is
      Current : Node_Ref := Find_Node (S, Facade);
      Item : Node_View;
      Property, Value : System.Address;
      P : Node_Ref;
      Length : Natural;
   begin
      Result := System.Null_Address;
      Space := Unspecified;
      Status := Invalid_Argument;
      if Current = Null_Node then
         return;
      end if;
      if Mode = Space_Property
        and then Node (S.Current.all, Current).Kind /= Element_Node
      then
         return;
      end if;
      for Step in 1 .. Node_Count (S.Current.all) loop
         pragma Loop_Invariant
           (Result = System.Null_Address and then Space = Unspecified);
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            return;
         end if;
         Item := Node (S.Current.all, Current);
         if Item.Kind = Element_Node then
            Find_Property
              (S, Item.Facade,
               (if Mode = Language_Property then "lang" else "space"),
               Exact_Namespace, XML3_Namespaces.XML_URI, Property, Status);
            if Status /= Created then
               return;
            end if;
            if Property /= System.Null_Address then
               if Mode = Language_Property then
                  Get_Content (S, Property, Result, Status);
                  return;
               end if;
               P := Find_Node (S, Property);
               if P = Null_Node then
                  Status := Internal_Error;
                  return;
               end if;
               Measure_Content (S, P, Length, Status);
               if Status /= Created then
                  return;
               end if;
               Get_Content (S, Property, Value, Status);
               if Status /= Created then
                  return;
               end if;
               if Equal_Bytes (Value, Length, "preserve") then
                  Space := Preserve_Space;
               elsif Equal_Bytes (Value, Length, "default") then
                  Space := Default_Space;
               end if;
               Native.Free (Value);
               if Space /= Unspecified then
                  return;
               end if;
            end if;
         end if;
         Current := Item.Parent;
      end loop;
      Status := (if Current = Null_Node then Created else Internal_Error);
   end Get_Inherited_XML_Property;

   procedure Get_Path
     (S : Store; Facade : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      Start : Node_Ref;
      Base : System.Address := System.Null_Address;
      Terminator : System.Address;
      Total : Natural := 0;

      function Valid_Name (Item : Node_View; Allow_Colon : Boolean)
        return Boolean
      is
      begin
         return Item.Name /= System.Null_Address
           and then Item.Name_Length > 0
           and then Item.Name_Length <= XML3_Text.Max_Bytes
           and then XML3_Text.Buffers.Valid_Name
             (Item.Name, Item.Name_Length, Allow_Colon);
      end Valid_Name;

      procedure Namespace_Item
        (N : Namespace_Ref; Item : out Namespace_View;
         Good : out Boolean)
        with Pre => S.Current /= null
          and then XML3_DOM.Valid (S.Current.all),
          Post => (if Good then
            (Item.Prefix = System.Null_Address
             and then Item.Prefix_Length = 0)
            or else
              (Item.Prefix /= System.Null_Address
               and then Item.Prefix_Length in 1 .. XML3_Text.Max_Bytes))
      is
      begin
         Item := (others => <>);
         Good := False;
         if not Live_Namespace (S, N) then
            return;
         end if;
         Item := Namespace (S.Current.all, N);
         if (Item.Prefix = System.Null_Address
             and then Item.Prefix_Length /= 0)
           or else
             (Item.Prefix /= System.Null_Address
              and then
                (Item.Prefix_Length = 0
                 or else Item.Prefix_Length > XML3_Text.Max_Bytes
                 or else not XML3_Text.Buffers.Valid_Name
                   (Item.Prefix, Item.Prefix_Length, False)))
         then
            return;
         end if;
         Good := True;
      end Namespace_Item;

      procedure Matches
        (Current, Candidate : Node_View;
         Match : out Boolean; Local_Status : out Operation_Status)
        with Pre => S.Current /= null
          and then XML3_DOM.Valid (S.Current.all)
      is
         Left_Ns, Right_Ns : Namespace_View;
         Left_Good, Right_Good : Boolean;
      begin
         Match := False;
         Local_Status := Created;
         if Current.Kind /= Candidate.Kind
           and then not
             (Is_Text_Content (Current.Kind)
              and then Is_Text_Content (Candidate.Kind))
         then
            return;
         end if;
         if Current.Kind = Element_Node then
            if not Valid_Name (Current, False)
              or else not Valid_Name (Candidate, False)
            then
               Local_Status := Invalid_Argument;
               return;
            end if;
            if Current.Namespace = Null_Namespace then
               Match := Candidate.Namespace = Null_Namespace
                 and then Equal_Address_Bytes
                   (Current.Name, Current.Name_Length,
                    Candidate.Name, Candidate.Name_Length);
               return;
            end if;
            Namespace_Item (Current.Namespace, Left_Ns, Left_Good);
            if not Left_Good then
               Local_Status := Invalid_Argument;
               return;
            end if;
            if Left_Ns.Prefix = System.Null_Address then
               Match := Candidate.Kind = Element_Node;
               if Candidate.Namespace /= Null_Namespace then
                  Namespace_Item (Candidate.Namespace, Right_Ns, Right_Good);
                  if not Right_Good then
                     Local_Status := Invalid_Argument;
                  end if;
               end if;
               return;
            end if;
            if Candidate.Namespace = Null_Namespace then
               return;
            end if;
            Namespace_Item (Candidate.Namespace, Right_Ns, Right_Good);
            if not Right_Good then
               Local_Status := Invalid_Argument;
               return;
            end if;
            Match := Equal_Address_Bytes
              (Current.Name, Current.Name_Length,
               Candidate.Name, Candidate.Name_Length)
              and then
                (Current.Namespace = Candidate.Namespace
                 or else
                   (Left_Ns.Prefix /= System.Null_Address
                    and then Right_Ns.Prefix /= System.Null_Address
                    and then Equal_Address_Bytes
                      (Left_Ns.Prefix, Left_Ns.Prefix_Length,
                       Right_Ns.Prefix, Right_Ns.Prefix_Length)));
         elsif Current.Kind = Attribute_Node then
            if not Valid_Name (Current, False)
              or else not Valid_Name (Candidate, False)
            then
               Local_Status := Invalid_Argument;
               return;
            end if;
            if Current.Namespace /= Null_Namespace then
               Namespace_Item (Current.Namespace, Left_Ns, Left_Good);
               if not Left_Good then
                  Local_Status := Invalid_Argument;
                  return;
               end if;
            end if;
            if Candidate.Namespace /= Null_Namespace then
               Namespace_Item (Candidate.Namespace, Right_Ns, Right_Good);
               if not Right_Good then
                  Local_Status := Invalid_Argument;
                  return;
               end if;
            end if;
            Match := Equal_Address_Bytes
              (Current.Name, Current.Name_Length,
               Candidate.Name, Candidate.Name_Length)
              and then Current.Namespace = Candidate.Namespace;
         elsif Current.Kind = Processing_Instruction_Node then
            if not Valid_Name (Current, True)
              or else not Valid_Name (Candidate, True)
            then
               Local_Status := Invalid_Argument;
               return;
            end if;
            Match := Equal_Address_Bytes
              (Current.Name, Current.Name_Length,
               Candidate.Name, Candidate.Name_Length);
         elsif Current.Kind = Comment_Node then
            Match := Candidate.Kind = Comment_Node;
         elsif Is_Text_Content (Current.Kind) then
            Match := Is_Text_Content (Candidate.Kind);
         end if;
      end Matches;

      procedure Occurrence
        (N : Node_Ref; Item : Node_View;
         Number : out Natural; Multiple : out Boolean;
         Local_Status : out Operation_Status)
        with Pre => S.Current /= null
          and then XML3_DOM.Valid (S.Current.all)
      is
         Parent_Item, Candidate : Node_View;
         Cursor, First, Last, Leftmost, Rightmost : Node_Ref;
         Expected_Next : Node_Ref := N;
         Expected_Previous : Node_Ref := N;
         Previous_Count, Following_Count : Natural := 0;
         Match : Boolean;
         Match_Status : Operation_Status;
      begin
         Number := 1;
         Multiple := False;
         Local_Status := Created;
         if Item.Parent = Null_Node then
            if Item.Previous /= Null_Node or else Item.Next /= Null_Node then
               Local_Status := Internal_Error;
            end if;
            return;
         end if;
         if not Live_Node (S, Item.Parent) then
            Local_Status := Internal_Error;
            return;
         end if;
         Parent_Item := Node (S.Current.all, Item.Parent);
         if Item.Kind = Attribute_Node then
            First := Parent_Item.First_Prop;
            Last := Parent_Item.Last_Prop;
         else
            First := Parent_Item.First_Child;
            Last := Parent_Item.Last_Child;
         end if;
         if First = Null_Node or else Last = Null_Node then
            Local_Status := Internal_Error;
            return;
         end if;
         Leftmost := N;
         Rightmost := N;
         Cursor := Item.Previous;
         for Step in 1 .. Node_Count (S.Current.all) loop
            exit when Cursor = Null_Node;
            if not Live_Node (S, Cursor) then
               Local_Status := Internal_Error;
               return;
            end if;
            Candidate := Node (S.Current.all, Cursor);
            if Candidate.Parent /= Item.Parent
              or else Candidate.Next /= Expected_Next
            then
               Local_Status := Internal_Error;
               return;
            end if;
            Matches (Item, Candidate, Match, Match_Status);
            if Match_Status /= Created then
               Local_Status := Match_Status;
               return;
            end if;
            if Match then
               if Previous_Count = Natural'Last then
                  Local_Status := Limit_Exceeded;
                  return;
               end if;
               Previous_Count := Previous_Count + 1;
            end if;
            Expected_Next := Cursor;
            Leftmost := Cursor;
            Cursor := Candidate.Previous;
         end loop;
         if Cursor /= Null_Node then
            Local_Status := Internal_Error;
            return;
         end if;
         if Leftmost /= First then
            Local_Status := Internal_Error;
            return;
         end if;
         Cursor := Item.Next;
         for Step in 1 .. Node_Count (S.Current.all) loop
            exit when Cursor = Null_Node;
            if not Live_Node (S, Cursor) then
               Local_Status := Internal_Error;
               return;
            end if;
            Candidate := Node (S.Current.all, Cursor);
            if Candidate.Parent /= Item.Parent
              or else Candidate.Previous /= Expected_Previous
            then
               Local_Status := Internal_Error;
               return;
            end if;
            Matches (Item, Candidate, Match, Match_Status);
            if Match_Status /= Created then
               Local_Status := Match_Status;
               return;
            end if;
            if Match then
               if Following_Count = Natural'Last then
                  Local_Status := Limit_Exceeded;
                  return;
               end if;
               Following_Count := Following_Count + 1;
            end if;
            Expected_Previous := Cursor;
            Rightmost := Cursor;
            Cursor := Candidate.Next;
         end loop;
         if Cursor /= Null_Node or else Rightmost /= Last then
            Local_Status := Internal_Error;
            return;
         end if;
         if Previous_Count = Natural'Last then
            Local_Status := Limit_Exceeded;
            return;
         end if;
         Number := Previous_Count + 1;
         Multiple := Previous_Count /= 0 or else Following_Count /= 0;
      end Occurrence;

      function Decimal_Digits (Value : Natural) return Natural is
         N : Natural := Value;
         Count : Natural := 1;
      begin
         while N >= 10 loop
            pragma Loop_Invariant (Count <= Natural'Width);
            pragma Loop_Variant (Decreases => N);
            N := N / 10;
            if Count = Natural'Width then
               return Count;
            end if;
            Count := Count + 1;
         end loop;
         return Count;
      end Decimal_Digits;

      procedure Component_Length
        (N : Node_Ref; Item : Node_View; Length : out Natural;
         Number : out Natural; Multiple : out Boolean;
         Local_Status : out Operation_Status)
        with Pre => S.Current /= null
          and then XML3_DOM.Valid (S.Current.all)
      is
         Prefix_Length : Natural := 0;
         Default_Namespace : Boolean := False;

         procedure Add_Length (Amount : Natural) is
         begin
            if Local_Status /= Created then
               return;
            end if;
            if Amount > XML3_Text.Max_Bytes - Length then
               Local_Status := Limit_Exceeded;
            else
               Length := Length + Amount;
            end if;
         end Add_Length;
      begin
         Length := 0;
         Number := 1;
         Multiple := False;
         Local_Status := Created;
         if Item.Kind = Document_Node then
            Length := 1;
            return;
         elsif Item.Kind = Element_Node then
            if not Valid_Name (Item, False) then
               Local_Status := Invalid_Argument;
               return;
            end if;
            if Item.Namespace /= Null_Namespace then
               declare
                  Ns : Namespace_View;
                  Good : Boolean;
               begin
                  Namespace_Item (Item.Namespace, Ns, Good);
                  if not Good then
                     Local_Status := Invalid_Argument;
                     return;
                  end if;
                  Prefix_Length := Ns.Prefix_Length;
                  Default_Namespace := Ns.Prefix = System.Null_Address;
               end;
            end if;
            Occurrence (N, Item, Number, Multiple, Local_Status);
            if Local_Status /= Created then
               return;
            end if;
            if Default_Namespace then
               Length := 2;
            else
               Add_Length (1);
               if Local_Status = Created then
                  Add_Length (Prefix_Length);
               end if;
               if Local_Status = Created
                 and then Prefix_Length > 0
               then
                  Add_Length (1);
               end if;
               if Local_Status = Created then
                  Add_Length (Item.Name_Length);
               end if;
            end if;
            if Local_Status = Created and then Multiple then
               Add_Length (Decimal_Digits (Number));
               Add_Length (2);
            end if;
         elsif Item.Kind = Attribute_Node then
            if not Valid_Name (Item, False) then
               Local_Status := Invalid_Argument;
               return;
            end if;
            if Item.Namespace /= Null_Namespace then
               declare
                  Ns : Namespace_View;
                  Good : Boolean;
               begin
                  Namespace_Item (Item.Namespace, Ns, Good);
                  if not Good then
                     Local_Status := Invalid_Argument;
                     return;
                  end if;
                  Prefix_Length := Ns.Prefix_Length;
               end;
            end if;
            Occurrence (N, Item, Number, Multiple, Local_Status);
            if Local_Status /= Created then
               return;
            end if;
            Length := 2;
            Add_Length (Prefix_Length);
            if Local_Status = Created and then Prefix_Length > 0 then
               Add_Length (1);
            end if;
            if Local_Status = Created then
               Add_Length (Item.Name_Length);
            end if;
         elsif Is_Text_Content (Item.Kind) then
            Occurrence (N, Item, Number, Multiple, Local_Status);
            if Local_Status /= Created then
               return;
            end if;
            Length := 7;
            if Multiple then
               Add_Length (Decimal_Digits (Number));
               Add_Length (2);
            end if;
         elsif Item.Kind = Comment_Node then
            Occurrence (N, Item, Number, Multiple, Local_Status);
            if Local_Status /= Created then
               return;
            end if;
            Length := 10;
            if Multiple then
               Add_Length (Decimal_Digits (Number));
               Add_Length (2);
            end if;
         elsif Item.Kind = Processing_Instruction_Node then
            if not Valid_Name (Item, True) then
               Local_Status := Invalid_Argument;
               return;
            end if;
            Occurrence (N, Item, Number, Multiple, Local_Status);
            if Local_Status /= Created then
               return;
            end if;
            Length := 27;
            Add_Length (Item.Name_Length);
            if Local_Status = Created and then Multiple then
               Add_Length (Decimal_Digits (Number));
               Add_Length (2);
            end if;
         else
            Local_Status := Invalid_Argument;
         end if;
      end Component_Length;

      procedure Write_Component
        (Item : Node_View; Base : System.Address; Start, Limit : Natural;
         Number : Natural; Multiple : Boolean;
         Local_Status : out Operation_Status)
        with Pre => S.Current /= null
          and then XML3_DOM.Valid (S.Current.all)
          and then Base /= System.Null_Address
          and then Start <= Limit
      is
         Cursor : Natural := Start;
         Target : System.Address := System.Null_Address;
         Digit_Count : Natural := 0;
         Expected_Digit_Count : constant Natural :=
           (if Multiple then Decimal_Digits (Number) else 0);
         Decimal_Chars : String (1 .. Natural'Width) := (others => '0');

         procedure Check_Span
           (Count : Natural; Target : out System.Address; Good : out Boolean)
           with Pre => Base /= System.Null_Address and then Cursor <= Limit,
             Post => (if Good then
               Count <= Limit - Cursor
                 and then Target /= System.Null_Address)
         is
         begin
            Target := System.Null_Address;
            Good := False;
            if Count > Limit - Cursor then
               return;
            end if;
            Target := Native.Offset (Base, Native.Byte_Count (Cursor));
            Good := Target /= System.Null_Address;
         end Check_Span;

         procedure Put_Literal (Value : String)
           with Pre => Base /= System.Null_Address and then Cursor <= Limit,
             Post => Cursor <= Limit
         is
            Can_Write : Boolean;
         begin
            if Local_Status /= Created then
               return;
            end if;
            Check_Span (Value'Length, Target, Can_Write);
            if not Can_Write then
               Local_Status := Internal_Error;
               return;
            end if;
            Native.Write_String (Base, Cursor, Value);
            Cursor := Cursor + Value'Length;
         end Put_Literal;

         procedure Put_Bytes (Source : System.Address; Count : Natural)
           with Pre => Base /= System.Null_Address and then Cursor <= Limit,
             Post => Cursor <= Limit
         is
            Can_Write : Boolean;
         begin
            if Local_Status /= Created then
               return;
            end if;
            if Count = 0 then
               return;
            end if;
            Check_Span (Count, Target, Can_Write);
            if not Can_Write then
               Local_Status := Internal_Error;
               return;
            end if;
            if Source = System.Null_Address then
               Local_Status := Internal_Error;
               return;
            end if;
            Native.Copy_Bytes (Source, Target, Count);
            Cursor := Cursor + Count;
         end Put_Bytes;

         procedure Put_Byte (Value : Character)
           with Pre => Base /= System.Null_Address and then Cursor <= Limit,
             Post => Cursor <= Limit
         is
            Can_Write : Boolean;
         begin
            if Local_Status /= Created then
               return;
            end if;
            Check_Span (1, Target, Can_Write);
            if not Can_Write then
               Local_Status := Internal_Error;
               return;
            end if;
            Native.Write_Byte (Base, Cursor, Value);
            Cursor := Cursor + 1;
         end Put_Byte;
      begin
         Local_Status := Created;
         if Multiple then
            if Number = 0 then
               Digit_Count := 1;
               Decimal_Chars (1) := '0';
            else
               declare
                  N : Natural := Number;
               begin
                  for I in Decimal_Chars'Range loop
                     exit when N = 0;
                     Decimal_Chars (I) := Character'Val
                       (Character'Pos ('0') + N mod 10);
                     N := N / 10;
                     Digit_Count := I;
                  end loop;
                  if N /= 0
                    or else Digit_Count /= Expected_Digit_Count
                  then
                     Local_Status := Internal_Error;
                     return;
                  end if;
               end;
            end if;
         end if;
         if Item.Kind = Document_Node then
            Put_Literal ("/");
         elsif Item.Kind = Element_Node then
            Put_Literal ("/");
            if Item.Namespace /= Null_Namespace then
               declare
                  Ns : Namespace_View;
                  Good : Boolean;
               begin
                  Namespace_Item (Item.Namespace, Ns, Good);
                  if not Good then
                     Local_Status := Invalid_Argument;
                     return;
                  end if;
                  if Ns.Prefix = System.Null_Address then
                     Put_Literal ("*");
                  else
                     Put_Bytes (Ns.Prefix, Ns.Prefix_Length);
                     Put_Literal (":");
                     Put_Bytes (Item.Name, Item.Name_Length);
                  end if;
               end;
            else
               Put_Bytes (Item.Name, Item.Name_Length);
            end if;
         elsif Item.Kind = Attribute_Node then
            Put_Literal ("/@");
            if Item.Namespace /= Null_Namespace then
               declare
                  Ns : Namespace_View;
                  Good : Boolean;
               begin
                  Namespace_Item (Item.Namespace, Ns, Good);
                  if not Good then
                     Local_Status := Invalid_Argument;
                     return;
                  end if;
                  if Ns.Prefix /= System.Null_Address then
                     Put_Bytes (Ns.Prefix, Ns.Prefix_Length);
                     Put_Literal (":");
                  end if;
               end;
            end if;
            Put_Bytes (Item.Name, Item.Name_Length);
         elsif Is_Text_Content (Item.Kind) then
            Put_Literal ("/text()");
         elsif Item.Kind = Comment_Node then
            Put_Literal ("/comment()");
         else
            Put_Literal ("/processing-instruction('");
            Put_Bytes (Item.Name, Item.Name_Length);
            Put_Literal ("')");
         end if;
         if Local_Status /= Created then
            return;
         end if;
         if (Item.Kind = Element_Node or else Is_Text_Content (Item.Kind)
             or else Item.Kind = Comment_Node
             or else Item.Kind = Processing_Instruction_Node)
           and then Multiple
         then
            Put_Byte ('[');
            for I in reverse 1 .. Digit_Count loop
               pragma Loop_Invariant (Cursor <= Limit);
               exit when Local_Status /= Created;
               Put_Byte (Decimal_Chars (I));
            end loop;
            Put_Byte (']');
         end if;
         if Local_Status = Created and then Cursor /= Limit then
            Local_Status := Internal_Error;
         end if;
      end Write_Component;

      procedure Measure (N : Node_Ref; Count : out Natural;
                         Local_Status : out Operation_Status)
        with Pre => S.Current /= null
          and then XML3_DOM.Valid (S.Current.all)
      is
         Current : Node_Ref := N;
         Item : Node_View;
         Length, Number : Natural;
         Multiple : Boolean;
      begin
         Count := 0;
         Local_Status := Created;
         for Step in 1 .. Node_Count (S.Current.all) loop
            exit when Current = Null_Node;
            if not Live_Node (S, Current) then
               Local_Status := Internal_Error;
               return;
            end if;
            Item := Node (S.Current.all, Current);
            if Current /= N and then Item.Kind = Document_Node then
               Current := Null_Node;
               exit;
            end if;
            Component_Length
              (Current, Item, Length, Number, Multiple, Local_Status);
            if Local_Status /= Created then
               return;
            end if;
            if Length > XML3_Text.Max_Bytes - Count then
               Local_Status := Limit_Exceeded;
               return;
            end if;
            Count := Count + Length;
            Current := Item.Parent;
         end loop;
         if Current /= Null_Node then
            Local_Status := Internal_Error;
         end if;
      end Measure;

      procedure Emit (N : Node_Ref; Base : System.Address; Expected : Natural;
                      Local_Status : out Operation_Status)
        with Pre => S.Current /= null
          and then XML3_DOM.Valid (S.Current.all)
          and then Base /= System.Null_Address
      is
         Current : Node_Ref := N;
         Item : Node_View;
         Length, Number, Used : Natural := 0;
         Multiple : Boolean;
      begin
         Local_Status := Created;
         for Step in 1 .. Node_Count (S.Current.all) loop
            exit when Current = Null_Node;
            if not Live_Node (S, Current) then
               Local_Status := Internal_Error;
               return;
            end if;
            Item := Node (S.Current.all, Current);
            if Current /= N and then Item.Kind = Document_Node then
               Current := Null_Node;
               exit;
            end if;
            Component_Length
              (Current, Item, Length, Number, Multiple, Local_Status);
            if Local_Status /= Created then
               return;
            end if;
            if Used > Expected or else Length > Expected - Used then
               Local_Status := Internal_Error;
               return;
            end if;
            Write_Component
              (Item, Base, Expected - Used - Length, Expected - Used,
               Number, Multiple,
               Local_Status);
            if Local_Status /= Created then
               return;
            end if;
            Used := Used + Length;
            Current := Item.Parent;
         end loop;
         if Current /= Null_Node or else Used /= Expected then
            Local_Status := Internal_Error;
         end if;
      end Emit;

      Local_Status : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if S.Current = null or else Facade = System.Null_Address then
         return;
      end if;
      Start := Find_Registered_Node (S, Facade);
      if Start = Null_Node or else not Live_Node (S, Start) then
         return;
      end if;
      Measure (Start, Total, Local_Status);
      if Local_Status /= Created then
         Status := Local_Status;
         return;
      end if;
      Native.Allocate (Native.Byte_Count (Total) + 1, Base);
      if Base = System.Null_Address then
         Status := No_Memory;
         return;
      end if;
      Emit (Start, Base, Total, Local_Status);
      if Local_Status /= Created then
         Native.Free (Base);
         Status := Local_Status;
         return;
      end if;
      Terminator := Native.Offset (Base, Native.Byte_Count (Total));
      if Terminator = System.Null_Address then
         Native.Free (Base);
         Status := Internal_Error;
         return;
      end if;
      Native.Write_Byte (Base, Total, Character'Val (0));
      Result := Base;
      Status := Created;
   end Get_Path;

   procedure Get_List_Content
     (S : Store; Facade : System.Address; Escape : Boolean;
      Result : out System.Address; Status : out Operation_Status;
      Doc : System.Address := System.Null_Address;
      Default_Entities : Boolean := False)
   is
      First, Current, Parent : Node_Ref;
      Item : Node_View;
      Total : XML3_Text.Byte_Count := 0;
      Attribute : Boolean := False;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if S.Current = null then
         return;
      end if;
      First := Find_Registered_Node (S, Facade);
      if First = Null_Node then
         return;
      end if;
      if Escape and then Default_Entities then
         if not Registered_Document (S, Doc) then
            return;
         end if;
         Parent := Node (S.Current.all, First).Parent;
         if Parent /= Null_Node then
            if not Live_Node (S, Parent) then
               return;
            end if;
            Attribute := Node (S.Current.all, Parent).Kind = Attribute_Node;
         end if;
      end if;
      Status := Internal_Error;
      Current := First;
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            return;
         end if;
         Item := Node (S.Current.all, Current);
         if Is_Text_Content (Item.Kind) then
            if Item.Content_Length > 0
              and then Item.Content = System.Null_Address
            then
               return;
            end if;
            if Item.Content_Length > XML3_Text.Max_Bytes - Total then
               Status := Limit_Exceeded;
               return;
            end if;
            Total := Total + Item.Content_Length;
         end if;
         Current := Item.Next;
      end loop;
      if Current /= Null_Node then
         return;
      end if;
      declare
         Content_Length : constant XML3_Text.Byte_Count := Total;
         Content : String (1 .. Content_Length) := (others => Character'Val (0));
         Cursor : Natural := 0;
         Escaping : XML3_Text.Buffers.Escape_Status;
      begin
         Current := First;
         for Step in 1 .. Node_Count (S.Current.all) loop
            pragma Loop_Invariant (Cursor <= Total);
            exit when Current = Null_Node;
            if not Live_Node (S, Current) then
               return;
            end if;
            Item := Node (S.Current.all, Current);
            if Is_Text_Content (Item.Kind) and then Item.Content_Length > 0 then
               if Item.Content = System.Null_Address
                 or else Item.Content_Length > Total - Cursor
               then
                  return;
               end if;
               Native.Read_String
                 (Item.Content, Content (Cursor + 1 .. Cursor + Item.Content_Length));
               if Escape and then not XML3_Text.Valid_UTF8
                 (Content (Cursor + 1 .. Cursor + Item.Content_Length))
               then
                  Status := Invalid_Argument;
                  return;
               end if;
               Cursor := Cursor + Item.Content_Length;
            end if;
            Current := Item.Next;
         end loop;
         if Current /= Null_Node or else Cursor /= Total then
            return;
         end if;
         if Escape then
            XML3_Text.Buffers.Escape_Special
              (Content, Result, Escaping, Non_ASCII => Default_Entities,
               Attribute => Attribute, Quotes => not Default_Entities);
            Status := Encoding_Status (Escaping);
         else
            XML3_Text.Buffers.Duplicate (Content, Result);
            Status := (if Result = System.Null_Address then No_Memory else Created);
         end if;
      end;
   end Get_List_Content;

   procedure Get_Content
     (S : Store; Facade : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      N : Node_Ref;
      Item : Node_View;
      Total : Natural;
      Base : System.Address;
      Measure_Status : Operation_Status;
      Copy_Status : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if S.Current = null then
         return;
      end if;
      N := Find_Node (S, Facade);
      if N = Null_Node then
         return;
      end if;
      Item := Node (S.Current.all, N);
      if Is_Text_Content (Item.Kind)
        or else Item.Kind = Comment_Node
        or else Item.Kind = Processing_Instruction_Node
      then
         if Item.Content_Length > 0
           and then Item.Content = System.Null_Address
         then
            Status := Internal_Error;
            return;
         end if;
         Total := Item.Content_Length;
      elsif Item.Kind = Document_Node
        or else Item.Kind = Element_Node
        or else Item.Kind = Attribute_Node
      then
         Measure_Content (S, N, Total, Measure_Status);
         if Measure_Status /= Created then
            Status := Measure_Status;
            return;
         end if;
      else
         Status := Invalid_Argument;
         return;
      end if;
      if Native.Byte_Count (Total) = Native.Byte_Count'Last then
         Status := Limit_Exceeded;
         return;
      end if;
      Native.Allocate (Native.Byte_Count (Total) + 1, Base);
      if Base = System.Null_Address then
         Status := No_Memory;
         return;
      end if;
      if Item.Kind = Text_Node
        or else Item.Kind = CData_Node
        or else Item.Kind = Comment_Node
        or else Item.Kind = Processing_Instruction_Node
      then
         Native.Copy_Bytes
           (Item.Content, Base, Item.Content_Length);
         Copy_Status := Created;
      else
         Copy_Content (S, N, Base, Total, Copy_Status);
      end if;
      if Copy_Status /= Created then
         Native.Free (Base);
         Status := Copy_Status;
         return;
      end if;
      Native.Write_Byte (Base, Total, Character'Val (0));
      Result := Base;
      Status := Created;
   end Get_Content;
end XML3_DOM_Store.Queries;
