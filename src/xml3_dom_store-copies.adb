with XML3_DOM_Store.Content;
with XML3_DOM_Store.Queries;

package body XML3_DOM_Store.Copies with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   package Native renames XML3_Native_Memory;
   package Queries renames XML3_DOM_Store.Queries;

   --  xmlNewReconciledNs keeps at most this many bytes of the original
   --  prefix and tries the numbered variants 1 .. Max_Counter.
   Max_Prefix_Bytes : constant := 20;
   Max_Counter : constant := 1_000;
   Max_Candidate : constant := Max_Prefix_Bytes + 4;

   --  The Store invariant, stated without calling the parent's Ready: a
   --  call to Ready from this child unit would itself require it.
   function Usable (S : Store) return Boolean is
     (S.Current = null
      or else (XML3_DOM.Valid (S.Current.all)
               and then XML3_DOM.Can_Edit (S.Current.all)
               and then not XML3_DOM.Projection_Required (S.Current.all)
               and then XML3_DOM.Facades_Present (S.Current.all)))
   with Ghost;

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
     (S.Current /= null
      and then Node_In_Range (S, N)
      and then Node (S.Current.all, N).State = XML3_DOM.Live)
     with Pre => Usable (S),
       Post => (if Live_Node'Result then
         S.Current /= null
         and then N in 1 .. Node_Ref (Capacity_Of (S.Current.all)));

   function Live_Namespace (S : Store; N : Namespace_Ref) return Boolean is
     (S.Current /= null
      and then Namespace_In_Range (S, N)
      and then Namespace (S.Current.all, N).State = XML3_DOM.Live)
     with Pre => Usable (S),
       Post => (if Live_Namespace'Result then
         S.Current /= null
         and then N in 1 .. Namespace_Ref (Capacity_Of (S.Current.all)));

   --  The facade of a node reference, or Null_Address for none.
   procedure Facade_Of
     (S : Store; N : Node_Ref; Result : out System.Address;
      Ok : out Boolean)
     with Global => null,
       Pre => Usable (S)
   is
   begin
      Result := System.Null_Address;
      Ok := True;
      if N = Null_Node then
         return;
      elsif not Live_Node (S, N) then
         Ok := False;
         return;
      end if;
      Result := Node (S.Current.all, N).Facade;
   end Facade_Of;

   --  The view of a registered namespace facade.
   procedure Namespace_Of
     (S : Store; Facade : System.Address; View : out Namespace_View;
      Ok : out Boolean)
     with Global => (Input => Native.Foreign_Memory),
       Pre => Usable (S)
   is
      N : Namespace_Ref;
   begin
      View := (others => <>);
      Ok := False;
      if Facade = System.Null_Address or else S.Current = null then
         return;
      end if;
      N := Find_Namespace (S, Facade);
      if not Live_Namespace (S, N) then
         return;
      end if;
      View := Namespace (S.Current.all, N);
      Ok := True;
   end Namespace_Of;

   --  xmlStrEqual on two namespace names.
   function Same_Href (Left, Right : Namespace_View) return Boolean is
     (if Left.Href = System.Null_Address
        or else Right.Href = System.Null_Address
      then Left.Href = Right.Href
      else Left.Href_Length = Right.Href_Length
        and then Native.Equal_Bytes
                   (Left.Href, Right.Href, Left.Href_Length))
     with Global => (Input => Native.Foreign_Memory);

   --  The topmost ancestor of N.  With Skip_Document, a document at the
   --  top is replaced by its child on the path from N, as
   --  xmlCopyPropInternal does.
   procedure Top_Of
     (S : Store; N : Node_Ref; Skip_Document : Boolean;
      Root : out Node_Ref; Ok : out Boolean)
     with Global => null,
       Pre => Usable (S)
   is
      Below : Node_Ref := Null_Node;
      Up : Node_Ref;
   begin
      Root := N;
      Ok := False;
      if not Live_Node (S, N) then
         return;
      end if;
      for Step in 1 .. Node_Count (S.Current.all) loop
         Up := Node (S.Current.all, Root).Parent;
         if Up = Null_Node then
            if Skip_Document
              and then Node (S.Current.all, Root).Kind = Document_Node
            then
               if Below = Null_Node then
                  return;
               end if;
               Root := Below;
            end if;
            Ok := True;
            return;
         end if;
         if not Live_Node (S, Up) then
            return;
         end if;
         Below := Root;
         Root := Up;
         pragma Loop_Invariant (Live_Node (S, Root));
      end loop;
   end Top_Of;

   --  Writes the decimal digits of Value after Text (1 .. Length).
   procedure Append_Number
     (Text : in out String; Length : in out Natural; Value : Positive)
     with Global => null,
       Pre => Text'First = 1 and then Text'Last = Max_Candidate
         and then Length <= Max_Prefix_Bytes
         and then Value <= Max_Counter,
       Post => Length <= Max_Candidate
   is
      Digits_Text : String (1 .. 4) := (others => '0');
      Count : Natural := 0;
      Rest : Natural := Value;
   begin
      for Position in reverse 1 .. 4 loop
         Digits_Text (Position) :=
           Character'Val (Character'Pos ('0') + Rest mod 10);
         Rest := Rest / 10;
         Count := Count + 1;
         exit when Rest = 0;
         pragma Loop_Invariant (Count = 5 - Position);
      end loop;
      for Index in 1 .. Count loop
         Text (Length + Index) := Digits_Text (4 - Count + Index);
         pragma Loop_Invariant (Length + Index <= Max_Candidate);
      end loop;
      Length := Length + Count;
   end Append_Number;

   --  xmlNewReconciledNs: an in-scope declaration of Original's name, or a
   --  new declaration on Tree with a prefix derived from Original's.
   procedure Reconcile
     (S : in out Store; Tree : System.Address; Original : Namespace_View;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
         and then (if Status /= Created then Result = System.Null_Address)
   is
      T : constant Node_Ref :=
        (if S.Current = null then Null_Node else Find_Node (S, Tree));
      Base_Length : Natural;
      Candidate : String (1 .. Max_Candidate) := (others => ' ');
      Candidate_Length : Natural;
      Existing : System.Address;
      Counter : Positive := 1;
   begin
      Result := System.Null_Address;
      Status := Internal_Error;
      if not Live_Node (S, T)
        or else Node (S.Current.all, T).Kind /= Element_Node
      then
         return;
      end if;
      if Original.Href /= System.Null_Address then
         Queries.Lookup_Namespace
           (S, Tree, Queries.Href_Search, Original.Href, Result, Status);
         if Status /= Created or else Result /= System.Null_Address then
            return;
         end if;
      end if;
      if Original.Prefix = System.Null_Address then
         Candidate (1 .. 7) := "default";
         Base_Length := 7;
      else
         Base_Length := Natural'Min (Original.Prefix_Length, Max_Prefix_Bytes);
         for Index in 1 .. Base_Length loop
            Candidate (Index) := Native.Byte_At (Original.Prefix, Index - 1);
         end loop;
      end if;
      Candidate_Length := Base_Length;
      for Attempt in 0 .. Max_Counter loop
         Queries.Lookup_Namespace
           (S, Tree, Queries.Prefix_Search, True,
            Candidate (1 .. Candidate_Length), Existing, Status);
         if Status /= Created then
            Result := System.Null_Address;
            return;
         end if;
         exit when Existing = System.Null_Address;
         if Counter > Max_Counter then
            Status := Internal_Error;
            return;
         end if;
         Candidate_Length := Base_Length;
         Append_Number (Candidate, Candidate_Length, Counter);
         Counter := Counter + 1;
         pragma Loop_Invariant (Usable (S));
         pragma Loop_Invariant (Base_Length <= Max_Prefix_Bytes);
         pragma Loop_Invariant (Candidate_Length <= Max_Candidate);
         pragma Loop_Invariant (Counter = Attempt + 2);
      end loop;
      if Existing /= System.Null_Address then
         Status := Internal_Error;
         return;
      end if;
      declare
         Href_Text : String (1 .. Original.Href_Length) :=
           (others => Character'Val (0));
      begin
         if Original.Href /= System.Null_Address then
            Native.Read_String (Original.Href, Href_Text);
         end if;
         Create_Namespace
           (S, Tree, Href_Text, Candidate (1 .. Candidate_Length),
            Original.Href /= System.Null_Address, True, Result, Status);
      end;
   end Reconcile;

   --  A copy of Src without links, properties or namespaces.
   procedure Copy_Shell
     (S : in out Store; Src : Node_Ref; Doc : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
         and then (if Status = Created then Result /= System.Null_Address
                   else Result = System.Null_Address)
   is
      V : Node_View;
      Content_Length : Natural;
   begin
      Result := System.Null_Address;
      Status := Internal_Error;
      if not Live_Node (S, Src) then
         return;
      end if;
      V := Node (S.Current.all, Src);
      Content_Length :=
        (if V.Content = System.Null_Address then 0 else V.Content_Length);
      case V.Kind is
         when Element_Node =>
            Content.New_Doc_Content
              (S, Doc, Element_Node, "", "", False, Result, Status,
               Name_Source => V.Name,
               Source_Name_Length =>
                 (if V.Name = System.Null_Address then 0 else V.Name_Length));
         when Processing_Instruction_Node =>
            Content.New_Doc_Content
              (S, Doc, Processing_Instruction_Node, "", "",
               V.Content /= System.Null_Address, Result, Status,
               Content_Source => V.Content, Source_Length => Content_Length,
               Name_Source => V.Name,
               Source_Name_Length =>
                 (if V.Name = System.Null_Address then 0 else V.Name_Length));
         when Text_Node =>
            Content.New_Doc_Content
              (S, Doc, Text_Node, "text", "",
               V.Content /= System.Null_Address, Result, Status,
               Content_Source => V.Content, Source_Length => Content_Length);
         when Comment_Node =>
            Content.New_Doc_Content
              (S, Doc, Comment_Node, "comment", "",
               V.Content /= System.Null_Address, Result, Status,
               Content_Source => V.Content, Source_Length => Content_Length);
         when CData_Node =>
            Content.New_Doc_Content
              (S, Doc, CData_Node, "", "",
               V.Content /= System.Null_Address, Result, Status,
               Content_Source => V.Content, Source_Length => Content_Length);
         when Document_Node | Attribute_Node =>
            Status := Invalid_Argument;
      end case;
   end Copy_Shell;

   --  Releases an unattached copy after a failure; a failed release turns
   --  the failure into an internal error.
   procedure Discard
     (S : in out Store; Copy : System.Address; Kind : Release_Kind;
      Status : in out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
         and then Status in Status'Old | Internal_Error
   is
      Cleanup : Operation_Status;
   begin
      if Copy = System.Null_Address then
         return;
      end if;
      Release (S, Copy, Kind, False, Cleanup);
      if Cleanup /= Created then
         Status := Internal_Error;
      end if;
   end Discard;

   --  xmlCopyPropInternal: a copy of the attribute Src for the element
   --  Target (Null_Node for none), unattached.
   procedure Copy_Attribute
     (S : in out Store; Doc : System.Address; Target, Src : Node_Ref;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
         and then (if Status = Created then Result /= System.Null_Address
                   else Result = System.Null_Address)
   is
      Source : Node_View;
      Copy_Doc : System.Address := System.Null_Address;
      Attr, Target_Facade, Found, Parent_Facade, Child_Copy : System.Address;
      Original, Found_View : Namespace_View;
      Root : Node_Ref := Null_Node;
      Child : Node_Ref;
      Ok : Boolean;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if not Live_Node (S, Src)
        or else Node (S.Current.all, Src).Kind /= Attribute_Node
      then
         return;
      end if;
      if Target /= Null_Node
        and then (not Live_Node (S, Target)
          or else Node (S.Current.all, Target).Kind /= Element_Node)
      then
         return;
      end if;
      Source := Node (S.Current.all, Src);
      Status := Internal_Error;
      if Target /= Null_Node then
         Facade_Of (S, Node (S.Current.all, Target).Document, Copy_Doc, Ok);
      elsif Doc /= System.Null_Address then
         Copy_Doc := Doc;
         Ok := True;
      elsif Source.Parent /= Null_Node then
         if not Live_Node (S, Source.Parent) then
            return;
         end if;
         Facade_Of
           (S, Node (S.Current.all, Source.Parent).Document, Copy_Doc, Ok);
      elsif Source.First_Child /= Null_Node then
         if not Live_Node (S, Source.First_Child) then
            return;
         end if;
         Facade_Of
           (S, Node (S.Current.all, Source.First_Child).Document, Copy_Doc,
            Ok);
      else
         Ok := True;
      end if;
      if not Ok then
         return;
      end if;
      Content.New_Doc_Content
        (S, Copy_Doc, Attribute_Node, "", "", False, Attr, Status,
         Name_Source => Source.Name,
         Source_Name_Length =>
           (if Source.Name = System.Null_Address then 0
            else Source.Name_Length));
      if Status /= Created then
         return;
      end if;

      if Source.Namespace /= Null_Namespace and then Target /= Null_Node then
         if not Live_Namespace (S, Source.Namespace)
           or else not Live_Node (S, Target)
         then
            Status := Internal_Error;
            Discard (S, Attr, Namespaced_Attribute, Status);
            return;
         end if;
         Original := Namespace (S.Current.all, Source.Namespace);
         Target_Facade := Node (S.Current.all, Target).Facade;
         Queries.Lookup_Namespace
           (S, Target_Facade, Queries.Prefix_Search, Original.Prefix,
            Found, Status);
         if Status /= Created then
            Discard (S, Attr, Namespaced_Attribute, Status);
            return;
         end if;
         if Found = System.Null_Address then
            --  Declared out of the new scope: declare it again at the top
            --  of the target tree, or leave the copy without a namespace.
            Facade_Of (S, Source.Parent, Parent_Facade, Ok);
            if not Ok then
               Status := Internal_Error;
               Discard (S, Attr, Namespaced_Attribute, Status);
               return;
            end if;
            if Parent_Facade /= System.Null_Address then
               Queries.Lookup_Namespace
                 (S, Parent_Facade, Queries.Prefix_Search, Original.Prefix,
                  Found, Status);
               if Status /= Created then
                  Discard (S, Attr, Namespaced_Attribute, Status);
                  return;
               end if;
            end if;
            if Found /= System.Null_Address then
               Namespace_Of (S, Found, Found_View, Ok);
               if Ok then
                  Top_Of (S, Target, True, Root, Ok);
               end if;
               if Ok then
                  Facade_Of (S, Root, Target_Facade, Ok);
               end if;
               if not Ok then
                  Status := Internal_Error;
                  Discard (S, Attr, Namespaced_Attribute, Status);
                  return;
               end if;
               Create_Namespace
                 (S, Target_Facade, Found_View.Href, Found_View.Prefix,
                  Found, Status);
               if Status /= Created then
                  Discard (S, Attr, Namespaced_Attribute, Status);
                  return;
               end if;
            end if;
         else
            Namespace_Of (S, Found, Found_View, Ok);
            if not Ok then
               Status := Internal_Error;
               Discard (S, Attr, Namespaced_Attribute, Status);
               return;
            end if;
            if not Same_Href (Found_View, Original) then
               Reconcile (S, Target_Facade, Original, Found, Status);
               if Status /= Created then
                  Discard (S, Attr, Namespaced_Attribute, Status);
                  return;
               end if;
            end if;
         end if;
         if Found /= System.Null_Address then
            Set_Namespace (S, Attr, Found, Status);
            if Status /= Created then
               Discard (S, Attr, Namespaced_Attribute, Status);
               return;
            end if;
         end if;
      end if;

      if S.Current = null then
         Status := Internal_Error;
         Discard (S, Attr, Namespaced_Attribute, Status);
         return;
      end if;
      Child := Source.First_Child;
      for Step in 1 .. Node_Count (S.Current.all) loop
         exit when Child = Null_Node;
         if not Live_Node (S, Child) then
            Status := Internal_Error;
            Discard (S, Attr, Namespaced_Attribute, Status);
            return;
         end if;
         Copy_Shell (S, Child, Copy_Doc, Child_Copy, Status);
         if Status /= Created then
            Discard (S, Attr, Namespaced_Attribute, Status);
            return;
         end if;
         Attach (S, Attr, Child_Copy, False, Status);
         if Status /= Created then
            Discard (S, Child_Copy, Content_Node, Status);
            Discard (S, Attr, Namespaced_Attribute, Status);
            return;
         end if;
         if not Live_Node (S, Child) then
            Status := Internal_Error;
            Discard (S, Attr, Namespaced_Attribute, Status);
            return;
         end if;
         Child := Node (S.Current.all, Child).Next;
         pragma Loop_Invariant (Usable (S));
         pragma Loop_Invariant (Attr /= System.Null_Address);
      end loop;
      if Child /= Null_Node then
         Status := Internal_Error;
         Discard (S, Attr, Namespaced_Attribute, Status);
         return;
      end if;
      Result := Attr;
      Status := Created;
   end Copy_Attribute;

   --  The namespace of the element copy Copy of Src, as xmlStaticCopyNode
   --  selects it: a declaration in scope of the copy with the same
   --  prefix; else the declaration in scope of Src, declared again at the
   --  top of the copy; else a reconciled declaration on the copy.
   procedure Resolve_Element_Namespace
     (S : in out Store; Src : Node_Ref; Copy : System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
   is
      Source : Node_View;
      Original, Declared : Namespace_View;
      Found : System.Address;
      Root_Facade : System.Address := System.Null_Address;
      C, Root : Node_Ref;
      Ok : Boolean;
   begin
      Status := Internal_Error;
      if not Live_Node (S, Src) then
         return;
      end if;
      Source := Node (S.Current.all, Src);
      if Source.Namespace = Null_Namespace then
         Status := Created;
         return;
      elsif not Live_Namespace (S, Source.Namespace) then
         return;
      end if;
      Original := Namespace (S.Current.all, Source.Namespace);
      Queries.Lookup_Namespace
        (S, Copy, Queries.Prefix_Search, Original.Prefix, Found, Status);
      if Status /= Created then
         return;
      end if;
      if Found = System.Null_Address then
         Queries.Lookup_Namespace
           (S, Source.Facade, Queries.Prefix_Search, Original.Prefix,
            Found, Status);
         if Status /= Created then
            return;
         end if;
         if Found /= System.Null_Address then
            Status := Internal_Error;
            Namespace_Of (S, Found, Declared, Ok);
            if not Ok or else S.Current = null then
               return;
            end if;
            C := Find_Node (S, Copy);
            Top_Of (S, C, False, Root, Ok);
            if Ok then
               Facade_Of (S, Root, Root_Facade, Ok);
            end if;
            if not Ok then
               return;
            end if;
            Create_Namespace
              (S, Root_Facade, Declared.Href, Declared.Prefix, Found, Status);
         else
            Reconcile (S, Copy, Original, Found, Status);
         end if;
         if Status /= Created then
            return;
         end if;
      end if;
      Set_Namespace (S, Copy, Found, Status);
   end Resolve_Element_Namespace;

   --  xmlCopyNamespaceList of the declarations of Src onto Copy.
   procedure Copy_Declarations
     (S : in out Store; Src : Node_Ref; Copy : System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
   is
      Ns : Namespace_Ref;
      Declared : Namespace_View;
      Created_Ns : System.Address;
   begin
      Status := Internal_Error;
      if not Live_Node (S, Src) then
         return;
      end if;
      Ns := Node (S.Current.all, Src).First_Namespace;
      for Step in 1 .. Namespace_Count (S.Current.all) loop
         exit when Ns = Null_Namespace;
         if not Live_Namespace (S, Ns) then
            Status := Internal_Error;
            return;
         end if;
         Declared := Namespace (S.Current.all, Ns);
         Create_Namespace
           (S, Copy, Declared.Href, Declared.Prefix, Created_Ns, Status);
         if Status /= Created then
            return;
         end if;
         Ns := Declared.Next;
         pragma Loop_Invariant (Usable (S));
      end loop;
      Status := (if Ns = Null_Namespace then Created else Internal_Error);
   end Copy_Declarations;

   --  xmlStaticCopyNode without the children: a copy of Src attached to
   --  Parent_Copy when given, with the namespaces and properties of an
   --  element when Details is set.  On failure, a copy that is not
   --  attached is released; an attached one is left to the caller.
   procedure Copy_One
     (S : in out Store; Src : Node_Ref; Doc, Parent_Copy : System.Address;
      Details : Boolean; Result : out System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
         and then (if Status = Created then Result /= System.Null_Address
                   else Result = System.Null_Address)
   is
      Copy, Attr : System.Address;
      C, Prop : Node_Ref;
      Element : Boolean;
   begin
      Result := System.Null_Address;
      Copy_Shell (S, Src, Doc, Copy, Status);
      if Status /= Created then
         return;
      end if;
      if Parent_Copy /= System.Null_Address then
         Attach (S, Parent_Copy, Copy, False, Status);
         if Status /= Created then
            Discard (S, Copy, Content_Node, Status);
            return;
         end if;
      end if;
      Element := Live_Node (S, Src)
        and then Node (S.Current.all, Src).Kind = Element_Node;
      if Details and then Element then
         Copy_Declarations (S, Src, Copy, Status);
         if Status = Created then
            Resolve_Element_Namespace (S, Src, Copy, Status);
         end if;
         if Status = Created then
            if S.Current = null or else not Live_Node (S, Src) then
               Status := Internal_Error;
            else
               Prop := Node (S.Current.all, Src).First_Prop;
               for Step in 1 .. Node_Count (S.Current.all) loop
                  exit when Prop = Null_Node;
                  C := Find_Node (S, Copy);
                  Copy_Attribute
                    (S, System.Null_Address, C, Prop, Attr, Status);
                  exit when Status /= Created;
                  Attach (S, Copy, Attr, True, Status);
                  if Status /= Created then
                     Discard (S, Attr, Namespaced_Attribute, Status);
                     exit;
                  end if;
                  if not Live_Node (S, Prop) then
                     Status := Internal_Error;
                     exit;
                  end if;
                  Prop := Node (S.Current.all, Prop).Next;
                  pragma Loop_Invariant (Usable (S));
                  pragma Loop_Invariant (Status = Created);
               end loop;
               if Status = Created and then Prop /= Null_Node then
                  Status := Internal_Error;
               end if;
            end if;
         end if;
         if Status /= Created then
            if Parent_Copy = System.Null_Address then
               Discard (S, Copy, Content_Node, Status);
            end if;
            return;
         end if;
      end if;
      Result := Copy;
      Status := Created;
   end Copy_One;

   --  xmlStaticCopyNode for a node that is neither an attribute nor a
   --  document: the copy of Src attached to Parent_Copy when given, and of
   --  its descendants for a deep copy, visited in document order.  On
   --  failure the copy is released unless it was attached.
   procedure Copy_Tree
     (S : in out Store; Src : Node_Ref; Doc, Parent_Copy : System.Address;
      Mode : Copy_Mode; Result : out System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
         and then (if Status = Created then Result /= System.Null_Address
                   else Result = System.Null_Address)
   is
      Top, Insert, Copy : System.Address;
      Cur, Up, I : Node_Ref;
      Limit : Natural;
      Advanced : Boolean;
   begin
      Result := System.Null_Address;
      Copy_One (S, Src, Doc, Parent_Copy, Mode /= Shallow, Top, Status);
      if Status /= Created then
         return;
      end if;
      if Mode = Deep then
         if not Live_Node (S, Src) then
            Status := Internal_Error;
         else
            Cur := Node (S.Current.all, Src).First_Child;
            Insert := Top;
            Limit :=
              (if Node_Count (S.Current.all) <= Natural'Last / 2 - 1
               then 2 * Node_Count (S.Current.all) + 2
               else Natural'Last);
            for Step in 1 .. Limit loop
               exit when Cur = Null_Node;
               Copy_One (S, Cur, Doc, Insert, True, Copy, Status);
               exit when Status /= Created;
               if not Live_Node (S, Cur) then
                  Status := Internal_Error;
                  exit;
               end if;
               if Node (S.Current.all, Cur).First_Child /= Null_Node then
                  Cur := Node (S.Current.all, Cur).First_Child;
                  Insert := Copy;
               else
                  Advanced := False;
                  for Climb in 1 .. Node_Count (S.Current.all) loop
                     if not Live_Node (S, Cur) then
                        Status := Internal_Error;
                        exit;
                     end if;
                     if Node (S.Current.all, Cur).Next /= Null_Node then
                        Cur := Node (S.Current.all, Cur).Next;
                        Advanced := True;
                        exit;
                     end if;
                     Cur := Node (S.Current.all, Cur).Parent;
                     if Cur = Src then
                        Cur := Null_Node;
                        Advanced := True;
                        exit;
                     end if;
                     I := Find_Node (S, Insert);
                     if not Live_Node (S, I) then
                        Status := Internal_Error;
                        exit;
                     end if;
                     Up := Node (S.Current.all, I).Parent;
                     if not Live_Node (S, Up) then
                        Status := Internal_Error;
                        exit;
                     end if;
                     Insert := Node (S.Current.all, Up).Facade;
                     pragma Loop_Invariant (Usable (S));
                     pragma Loop_Invariant (Status = Created);
                  end loop;
                  exit when Status /= Created;
                  if not Advanced then
                     Status := Internal_Error;
                     exit;
                  end if;
               end if;
               pragma Loop_Invariant (Usable (S));
               pragma Loop_Invariant (Status = Created);
            end loop;
            if Status = Created and then Cur /= Null_Node then
               Status := Internal_Error;
            end if;
         end if;
         if Status /= Created then
            if Parent_Copy = System.Null_Address then
               Discard (S, Top, Content_Node, Status);
            end if;
            return;
         end if;
      end if;
      Result := Top;
      Status := Created;
   end Copy_Tree;

   procedure Copy_Document_Node
     (S : in out Store; D : Node_Ref; Recursive : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => Native.Foreign_Memory),
       Pre => Usable (S),
       Post => Usable (S)
         and then (if Status = Created then Result /= System.Null_Address
                   else Result = System.Null_Address)
   is
      New_Doc, Copied : System.Address;
      Child : Node_Ref;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if not Live_Node (S, D)
        or else Node (S.Current.all, D).Kind /= Document_Node
      then
         return;
      end if;
      New_Document (S, Node (S.Current.all, D).Content, New_Doc, Status);
      if Status /= Created then
         return;
      end if;
      if Recursive then
         if not Live_Node (S, D) then
            Status := Internal_Error;
         else
            Child := Node (S.Current.all, D).First_Child;
            for Step in 1 .. Node_Count (S.Current.all) loop
               exit when Child = Null_Node;
               Copy_Tree (S, Child, New_Doc, New_Doc, Deep, Copied, Status);
               exit when Status /= Created;
               if not Live_Node (S, Child) then
                  Status := Internal_Error;
                  exit;
               end if;
               Child := Node (S.Current.all, Child).Next;
               pragma Loop_Invariant (Usable (S));
               pragma Loop_Invariant (Status = Created);
            end loop;
            if Status = Created and then Child /= Null_Node then
               Status := Internal_Error;
            end if;
         end if;
         if Status /= Created then
            Discard (S, New_Doc, Document_Only, Status);
            return;
         end if;
      end if;
      Result := New_Doc;
      Status := Created;
   end Copy_Document_Node;

   procedure Copy_Node
     (S : in out Store; Source, Doc : System.Address; Mode : Copy_Mode;
      Result : out System.Address; Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Registered_Node (S, Source);
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if N = Null_Node then
         return;
      end if;
      case Node (S.Current.all, N).Kind is
         when Document_Node =>
            Copy_Document_Node (S, N, Mode /= Shallow, Result, Status);
         when Attribute_Node =>
            Copy_Attribute (S, Doc, Null_Node, N, Result, Status);
         when others =>
            Copy_Tree
              (S, N, Doc, System.Null_Address, Mode, Result, Status);
      end case;
   end Copy_Node;

   procedure Copy_Property
     (S : in out Store; Target, Source : System.Address;
      Result : out System.Address; Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Registered_Node (S, Source);
      T : constant Node_Ref :=
        (if Target = System.Null_Address then Null_Node
         else Find_Registered_Node (S, Target));
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if N = Null_Node
        or else Node (S.Current.all, N).Kind /= Attribute_Node
        or else (Target /= System.Null_Address and then T = Null_Node)
      then
         return;
      end if;
      Copy_Attribute (S, System.Null_Address, T, N, Result, Status);
   end Copy_Property;

   procedure Copy_Document
     (S : in out Store; Source : System.Address; Recursive : Boolean;
      Result : out System.Address; Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Registered_Node (S, Source);
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if N = Null_Node then
         return;
      end if;
      Copy_Document_Node (S, N, Recursive, Result, Status);
   end Copy_Document;

end XML3_DOM_Store.Copies;
