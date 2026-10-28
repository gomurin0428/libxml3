with XML3_DOM_Constructors;
with XML3_Namespaces;

package body XML3_DOM_Store.Queries with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;

   procedure Find_Matching_Property
     (S : Store; Element, Attribute : System.Address;
      Result : out System.Address; Status : out Operation_Status)
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
         if Matches then
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
               if Native.Byte_At (V.Content, I) not in
                 ' ' | Character'Val (9) | Character'Val (10) | Character'Val (13)
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
         if not Has_Value then
            return Candidate.Prefix = System.Null_Address;
         end if;
         return Candidate.Prefix /= System.Null_Address
           and then Equal_Bytes
             (Candidate.Prefix, Candidate.Prefix_Length, Value);
      end if;
      return Has_Value
        and then Candidate.Href /= System.Null_Address
        and then Equal_Bytes (Candidate.Href, Candidate.Href_Length, Value);
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
      Resolved : out Namespace_Ref; Status : out Operation_Status)
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
            if Current /= Original then
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
         when Last_Element => N.Last_Child,
         when others => N.First_Child);
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when Current = Null_Node;
         if not Live_Node (S, Current) then
            Status := Internal_Error;
            Count := 0;
            return;
         end if;
         N := Node (S.Current.all, Current);
         if N.Kind = Element_Node then
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
      if S.Current = null
        or else (Mode = Href_Search and then not Has_Value)
      then
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
