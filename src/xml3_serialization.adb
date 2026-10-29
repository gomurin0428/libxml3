with XML3_Namespaces;
with XML3_Text;
with XML3_Text.Buffers;

package body XML3_Serialization with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   use XML3_DOM;
   use XML3_DOM_Constructors;
   use type Native.Byte_Count;
   use type XML3_Text.Text_Error_Kind;

   function Equal_Bytes
     (Base : System.Address; Length : Natural; Value : String) return Boolean
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

   function Same_Bytes
     (Left : System.Address; Left_Length : Natural;
      Right : System.Address; Right_Length : Natural) return Boolean
   is
   begin
      if Left_Length /= Right_Length then
         return False;
      elsif Left_Length = 0 then
         return True;
      elsif Left = System.Null_Address or else Right = System.Null_Address then
         return False;
      end if;
      for I in 0 .. Left_Length - 1 loop
         if Native.Byte_At (Left, I) /= Native.Byte_At (Right, I) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Bytes;

   function Is_UTF8 (Encoding : String) return Boolean is
      Expected : constant String := "UTF-8";
   begin
      if Encoding'Length /= Expected'Length then
         return False;
      end if;
      for I in Encoding'Range loop
         declare
            A : constant Character := Encoding (I);
            B : constant Character :=
              Expected (Expected'First + (I - Encoding'First));
         begin
            if A = B then
               null;
            elsif Character'Pos (A) in Character'Pos ('a') ..
                  Character'Pos ('z')
              and then Character'Pos (A) - Character'Pos ('a') =
                Character'Pos (B) - Character'Pos ('A')
            then
               null;
            elsif Character'Pos (A) in Character'Pos ('A') ..
                  Character'Pos ('Z')
              and then Character'Pos (A) - Character'Pos ('A') =
                Character'Pos (B) - Character'Pos ('a')
            then
               null;
            else
               return False;
            end if;
         end;
      end loop;
      return True;
   end Is_UTF8;

   procedure Render
     (Tree : XML3_DOM.State; Document : XML3_DOM.Node_Ref;
      Encoding : String; Result : out System.Address;
      Length : out Natural;
      Status : out XML3_DOM_Constructors.Construction_Status;
      Default_Encoding, Formatted : Boolean := False)
   is
      Cursor : Natural := 0;
      Capacity : Natural := Max_Output_Bytes;
      Base : System.Address := System.Null_Address;
      Writing : Boolean := False;
      Good : Boolean := True;
      Limit_Failure : Boolean := False;

      procedure Add (Amount : Natural) is
      begin
         if not Good or else Amount > Max_Output_Bytes - Cursor then
            Good := False;
            Limit_Failure := True;
         else
            Cursor := Cursor + Amount;
         end if;
      end Add;

      procedure Put (Value : String) is
      begin
         if Good then
            if Cursor > Capacity or else Value'Length > Capacity - Cursor then
               Good := False;
               Limit_Failure := not Writing;
            else
               if Writing and then Value'Length > 0 then
                  if Base = System.Null_Address then
                     Good := False;
                     return;
                  end if;
                  Native.Write_String (Base, Cursor, Value);
               end if;
               Add (Value'Length);
            end if;
         end if;
      end Put;

      procedure Put_Byte (Value : Character) is
      begin
         if Good then
            if Cursor >= Capacity then
               Good := False;
               Limit_Failure := not Writing;
            else
               if Writing then
                  if Base = System.Null_Address then
                     Good := False;
                     return;
                  end if;
                  Native.Write_Byte (Base, Cursor, Value);
               end if;
               Add (1);
            end if;
         end if;
      end Put_Byte;

      function Node_Is_Live (N : Node_Ref) return Boolean
        with Post =>
          (if Node_Is_Live'Result then
             N in 1 .. Node_Ref (Node_Count (Tree))
             and then N <= Node_Ref (Capacity_Of (Tree))
             and then Node (Tree, N).State = Live)
      is
      begin
         return N in 1 .. Node_Ref (Node_Count (Tree))
           and then N <= Node_Ref (Capacity_Of (Tree))
           and then Node (Tree, N).State = Live;
      end Node_Is_Live;

      function Equal_ASCII_Case_Insensitive
        (Source : System.Address; Source_Length : Natural;
         Value : String) return Boolean
      is
         function Fold_ASCII (Byte : Natural) return Natural is
         begin
            if Byte in Character'Pos ('A') .. Character'Pos ('Z') then
               return Byte + Character'Pos ('a') - Character'Pos ('A');
            else
               return Byte;
            end if;
         end Fold_ASCII;
      begin
         if Source_Length = 0 then
            return Value'Length = 0;
         elsif Source_Length /= Value'Length
           or else Source = System.Null_Address
         then
            return False;
         end if;
         for I in 0 .. Source_Length - 1 loop
            declare
               A : constant Natural := Fold_ASCII
                 (Character'Pos (Native.Byte_At (Source, I)));
               B : constant Natural := Fold_ASCII
                 (Character'Pos (Value (Value'First + I)));
            begin
               if A /= B then
                  return False;
               end if;
            end;
         end loop;
         return True;
      end Equal_ASCII_Case_Insensitive;

      function Contains_Pair
        (Source : System.Address; Source_Length : Natural;
         First, Second : Character) return Boolean
      is
      begin
         if Source_Length < 2 or else Source = System.Null_Address then
            return False;
         end if;
         for I in 0 .. Source_Length - 2 loop
            if Native.Byte_At (Source, I) = First
              and then Native.Byte_At (Source, I + 1) = Second
            then
               return True;
            end if;
         end loop;
         return False;
      end Contains_Pair;

      function Scalar_Width
        (Source : System.Address; Source_Length, Offset : Natural)
         return Natural
      is
         Window : String (1 .. 4) := (others => Character'Val (0));
         Count : Natural;
         B : Natural;
         W : Natural;
         Kind : XML3_Text.Text_Error_Kind;
         Error : Natural;
      begin
         if Source = System.Null_Address or else Offset >= Source_Length then
            return 0;
         end if;
         B := Character'Pos (Native.Byte_At (Source, Offset));
         if B < 16#80# then
            W := 1;
         elsif B in 16#C2# .. 16#DF# then
            W := 2;
         elsif B in 16#E0# .. 16#EF# then
            W := 3;
         elsif B in 16#F0# .. 16#F4# then
            W := 4;
         else
            return 0;
         end if;
         Count := Natural'Min (W, Source_Length - Offset);
         for I in 0 .. Count - 1 loop
            Window (I + 1) := Native.Byte_At (Source, Offset + I);
         end loop;
         XML3_Text.Validate_UTF8 (Window (1 .. Count), Kind, Error);
         if Kind /= XML3_Text.No_Text_Error then
            return 0;
         end if;
         return W;
      end Scalar_Width;

      function Valid_Text
        (Source : System.Address; Source_Length : Natural) return Boolean
      is
         I : Natural := 0;
         W : Natural;
      begin
         if Source_Length = 0 then
            return True;
         elsif Source = System.Null_Address then
            return False;
         end if;
         while I < Source_Length loop
            pragma Loop_Variant (Increases => I);
            W := Scalar_Width (Source, Source_Length, I);
            if W = 0 or else W > Source_Length - I then
               return False;
            end if;
            I := I + W;
         end loop;
         return True;
      end Valid_Text;

      function Valid_Name
        (Source : System.Address; Source_Length : Natural;
         Allow_Colon : Boolean) return Boolean
      is
         I : Natural := 0;
         W : Natural;
         Initial : Boolean := True;
         Window : String (1 .. 4) := (others => Character'Val (0));
      begin
         if Source_Length = 0 or else Source = System.Null_Address then
            return False;
         end if;
         while I < Source_Length loop
            pragma Loop_Variant (Increases => I);
            if Native.Byte_At (Source, I) = ':' then
               if not Allow_Colon then
                  return False;
               end if;
               Initial := False;
               I := I + 1;
            else
               W := Scalar_Width (Source, Source_Length, I);
               if W = 0 or else W > 4 or else W > Source_Length - I then
                  return False;
               end if;
               for J in 0 .. W - 1 loop
                  pragma Loop_Invariant (J < W);
                  Window (J + 1) := Native.Byte_At (Source, I + J);
               end loop;
               if XML3_Text.Name_Width
                    (Window (1 .. W), 1, Initial) /= W
               then
                  return False;
               end if;
               Initial := False;
               I := I + W;
            end if;
         end loop;
         return not Initial;
      end Valid_Name;

      procedure Put_Character_Reference (Code : Natural) is
         Hex : constant String := "0123456789ABCDEF";
         Buffer : String (1 .. 6) := (others => '0');
         First : Positive := Buffer'Last;
         Value : Natural := Code;
      begin
         loop
            pragma Loop_Invariant (First in Buffer'Range);
            pragma Loop_Variant (Decreases => Value);
            Buffer (First) := Hex ((Value mod 16) + 1);
            Value := Value / 16;
            exit when Value = 0;
            if First = Buffer'First then
               Good := False;
               return;
            end if;
            First := First - 1;
         end loop;
         Put ("&#x");
         Put (Buffer (First .. Buffer'Last));
         Put (";");
      end Put_Character_Reference;

      procedure Emit_Text
        (Source : System.Address; Source_Length : Natural;
         Attribute : Boolean; Uri : Boolean;
         Escape_Non_ASCII : Boolean)
      is
         I : Natural := 0;
         W : Natural;
         C : Character;
         Code : Integer;
         Decoded : Natural;
      begin
         if Source_Length = 0 then
            return;
         end if;
         if Source = System.Null_Address then
            Good := False;
            return;
         end if;
         while Good and then I < Source_Length loop
            pragma Loop_Variant (Increases => I);
            C := Native.Byte_At (Source, I);
            if C = '&' then
               Put ("&amp;");
               I := I + 1;
            elsif C = '<' then
               Put ("&lt;");
               I := I + 1;
            elsif C = '>' then
               Put ("&gt;");
               I := I + 1;
            elsif C = Character'Val (13) then
               Put ("&#13;");
               I := I + 1;
            elsif (Attribute or else Uri) and then C = '"' then
               Put ("&quot;");
               I := I + 1;
            elsif (Attribute or else Uri) and then C = Character'Val (9) then
               Put ("&#9;");
               I := I + 1;
            elsif (Attribute or else Uri) and then C = Character'Val (10) then
               Put ("&#10;");
               I := I + 1;
            else
               W := Scalar_Width (Source, Source_Length, I);
               if W = 0 or else W > Source_Length - I then
                  Good := False;
               elsif Default_Encoding and then Escape_Non_ASCII
                 and then W > 1
               then
                  XML3_Text.Buffers.Get_UTF8_Char
                    (Native.Offset (Source, Native.Byte_Count (I)), W,
                     Code, Decoded);
                  if Code < 0 or else Decoded /= W then
                     Good := False;
                  else
                     Put_Character_Reference (Natural (Code));
                  end if;
                  I := I + W;
               else
                  for J in 0 .. W - 1 loop
                     pragma Loop_Invariant (J < W);
                     Put_Byte (Native.Byte_At (Source, I + J));
                  end loop;
                  I := I + W;
               end if;
            end if;
         end loop;
      end Emit_Text;

      function In_Scope
        (Owner : Node_Ref;
         Prefix : System.Address; Prefix_Length : Natural;
         Href : System.Address; Href_Length : Natural) return Boolean
      is
         Current : Node_Ref := Owner;
         Ns : Namespace_Ref;
         Item : Namespace_View;
      begin
         if Prefix_Length = 3 and then Equal_Bytes (Prefix, Prefix_Length, "xml")
         then
            return Href_Length = XML3_Namespaces.XML_URI'Length
              and then Equal_Bytes
                (Href, Href_Length, XML3_Namespaces.XML_URI);
         end if;
         for Outer in 1 .. Node_Count (Tree) loop
            exit when Current = Null_Node;
            if not Node_Is_Live (Current) then
               return False;
            end if;
            if Node (Tree, Current).Kind = Element_Node then
               Ns := Node (Tree, Current).First_Namespace;
               for Inner in 1 .. Namespace_Count (Tree) loop
                  exit when Ns = Null_Namespace;
                  if Ns > Namespace_Ref (Namespace_Count (Tree))
                    or else Ns > Namespace_Ref (Capacity_Of (Tree))
                  then
                     return False;
                  end if;
                  Item := Namespace (Tree, Ns);
                  if Item.State /= Live or else Item.Href = System.Null_Address
                    or else (Item.Prefix /= System.Null_Address
                      and then Item.Prefix_Length = 0)
                  then
                     return False;
                  end if;
                  if Same_Bytes
                    (Item.Prefix, Item.Prefix_Length, Prefix, Prefix_Length)
                  then
                     return Same_Bytes
                       (Item.Href, Item.Href_Length, Href, Href_Length);
                  end if;
                  Ns := Item.Next;
               end loop;
               if Ns /= Null_Namespace then
                  return False;
               end if;
            end if;
            Current := Node (Tree, Current).Parent;
         end loop;
         return Current = Null_Node
           and then Prefix_Length = 0
           and then Href_Length = 0;
      end In_Scope;

      function Valid_Namespace_Value (Item : Namespace_View) return Boolean is
         Has_Prefix : constant Boolean :=
           Item.Prefix /= System.Null_Address;
         Is_XML_Prefix : constant Boolean :=
           Has_Prefix and then Equal_Bytes
             (Item.Prefix, Item.Prefix_Length, "xml");
      begin
         if Item.State /= Live or else Item.Href = System.Null_Address
           or else (Has_Prefix and then
             (Item.Prefix_Length = 0
              or else not Valid_Name
                (Item.Prefix, Item.Prefix_Length, False)))
           or else (not Has_Prefix and then Item.Prefix_Length /= 0)
           or else (Has_Prefix and then Item.Href_Length = 0)
           or else not Valid_Text (Item.Href, Item.Href_Length)
           or else Equal_Bytes
             (Item.Href, Item.Href_Length, XML3_Namespaces.XMLNS_URI)
           or else (Is_XML_Prefix and then not Equal_Bytes
             (Item.Href, Item.Href_Length, XML3_Namespaces.XML_URI))
           or else (not Is_XML_Prefix and then Equal_Bytes
             (Item.Href, Item.Href_Length, XML3_Namespaces.XML_URI))
           or else (Has_Prefix and then Equal_Bytes
             (Item.Prefix, Item.Prefix_Length, "xmlns"))
         then
            return False;
         end if;
         return True;
      end Valid_Namespace_Value;

      function Name_Namespace_Valid
        (N : Node_Ref; Attribute : Boolean) return Boolean
      is
         Item : Node_View;
         Ns_Item : Namespace_View;
         Prefix : System.Address := System.Null_Address;
         Prefix_Length : Natural := 0;
         Href : System.Address := System.Null_Address;
         Href_Length : Natural := 0;
      begin
         if not Node_Is_Live (N) then
            return False;
         end if;
         Item := Node (Tree, N);
         if Item.Namespace = Null_Namespace then
            return Attribute
              or else In_Scope
                (N, System.Null_Address, 0, System.Null_Address, 0);
         elsif Item.Namespace > Namespace_Ref (Namespace_Count (Tree))
           or else Item.Namespace > Namespace_Ref (Capacity_Of (Tree))
         then
            return False;
         end if;
         Ns_Item := Namespace (Tree, Item.Namespace);
         if not Valid_Namespace_Value (Ns_Item) then
            return False;
         end if;
         Prefix := Ns_Item.Prefix;
         Prefix_Length := Ns_Item.Prefix_Length;
         Href := Ns_Item.Href;
         Href_Length := Ns_Item.Href_Length;
         if Attribute
           and then (Href_Length = 0
                     or else Prefix = System.Null_Address
                     or else Prefix_Length = 0)
         then
            return False;
         end if;
         return In_Scope (N, Prefix, Prefix_Length, Href, Href_Length);
      end Name_Namespace_Valid;

      function Same_Expanded_Name (Left, Right : Node_Ref) return Boolean is
         L, R : Node_View;
         L_NS, R_NS : Namespace_View;
      begin
         if not Node_Is_Live (Left) then
            return False;
         elsif not Node_Is_Live (Right) then
            return False;
         end if;
         L := Node (Tree, Left);
         R := Node (Tree, Right);
         if not Same_Bytes
           (L.Name, L.Name_Length, R.Name, R.Name_Length)
         then
            return False;
         elsif L.Namespace = Null_Namespace then
            return R.Namespace = Null_Namespace;
         elsif R.Namespace = Null_Namespace
           or else L.Namespace > Namespace_Ref (Namespace_Count (Tree))
           or else L.Namespace > Namespace_Ref (Capacity_Of (Tree))
           or else R.Namespace > Namespace_Ref (Namespace_Count (Tree))
           or else R.Namespace > Namespace_Ref (Capacity_Of (Tree))
         then
            return False;
         end if;
         L_NS := Namespace (Tree, L.Namespace);
         R_NS := Namespace (Tree, R.Namespace);
         return Valid_Namespace_Value (L_NS)
           and then Valid_Namespace_Value (R_NS)
           and then Same_Bytes
             (L_NS.Href, L_NS.Href_Length, R_NS.Href, R_NS.Href_Length);
      end Same_Expanded_Name;

      function Child_Link_Valid
        (Parent, Child : Node_Ref) return Boolean
      is
         P, C, Sibling : Node_View;
      begin
         if not Node_Is_Live (Parent) then
            return False;
         elsif not Node_Is_Live (Child) then
            return False;
         end if;
         P := Node (Tree, Parent);
         C := Node (Tree, Child);
         if C.Parent /= Parent then
            return False;
         elsif C.Previous = Null_Node then
            if P.First_Child /= Child then
               return False;
            end if;
         elsif not Node_Is_Live (C.Previous) then
            return False;
         else
            Sibling := Node (Tree, C.Previous);
            if Sibling.Next /= Child or else Sibling.Parent /= Parent then
               return False;
            end if;
         end if;
         if C.Next /= Null_Node then
            if not Node_Is_Live (C.Next) then
               return False;
            end if;
            Sibling := Node (Tree, C.Next);
            if Sibling.Previous /= Child or else Sibling.Parent /= Parent then
               return False;
            end if;
         elsif P.Last_Child /= Child then
            return False;
         end if;
         return True;
      end Child_Link_Valid;

      procedure Put_Source
        (Source : System.Address; Length : Natural);

      procedure Put_Name (N : Node_Ref; Attribute : Boolean := False) is
         Item : Node_View;
         Ns_Item : Namespace_View;
      begin
         if not Node_Is_Live (N) then
            Good := False;
            return;
         end if;
         Item := Node (Tree, N);
         if not Name_Namespace_Valid (N, Attribute) then
            Good := False;
            return;
         end if;
         if Item.Namespace /= Null_Namespace then
            if Item.Namespace > Namespace_Ref (Namespace_Count (Tree))
              or else Item.Namespace > Namespace_Ref (Capacity_Of (Tree))
            then
               Good := False;
               return;
            end if;
            Ns_Item := Namespace (Tree, Item.Namespace);
            if Ns_Item.Prefix = System.Null_Address
              or else Ns_Item.Prefix_Length = 0
            then
               if Attribute and then Ns_Item.Href_Length > 0 then
                  Good := False;
                  return;
               end if;
            else
               Put_Source (Ns_Item.Prefix, Ns_Item.Prefix_Length);
               Put (":");
            end if;
         elsif not Attribute then
            null;
         end if;
         if Item.Name = System.Null_Address
           or else not Valid_Name (Item.Name, Item.Name_Length, False)
         then
            Good := False;
         else
            Emit_Text (Item.Name, Item.Name_Length, False, False, False);
         end if;
      end Put_Name;

      procedure Put_Source
        (Source : System.Address; Length : Natural) is
      begin
         if Length = 0 then
            return;
         elsif Source = System.Null_Address then
            Good := False;
         else
            for I in 0 .. Length - 1 loop
               Put_Byte (Native.Byte_At (Source, I));
            end loop;
         end if;
      end Put_Source;

      procedure Put_Namespaces (N : Node_Ref) is
         Ns : Namespace_Ref;
         Item, Prior_Item : Namespace_View;
         Previous, Last : Namespace_Ref := Null_Namespace;
         Candidate : Namespace_Ref;
      begin
         if not Node_Is_Live (N) then
            Good := False;
            return;
         end if;
         Ns := Node (Tree, N).First_Namespace;
         for Step in 1 .. Namespace_Count (Tree) loop
            exit when Ns = Null_Namespace;
            if Ns > Namespace_Ref (Namespace_Count (Tree))
              or else Ns > Namespace_Ref (Capacity_Of (Tree))
            then
               Good := False;
               return;
            end if;
            Item := Namespace (Tree, Ns);
            if not Valid_Namespace_Value (Item)
              or else not Item.Attached
              or else Item.Parent /= N
              or else Item.Previous /= Previous
            then
               Good := False;
               return;
            end if;
            Candidate := Node (Tree, N).First_Namespace;
            for Earlier in 1 .. Namespace_Count (Tree) loop
               exit when Candidate = Ns;
               if Candidate = Null_Namespace
                 or else Candidate > Namespace_Ref (Namespace_Count (Tree))
                 or else Candidate > Namespace_Ref (Capacity_Of (Tree))
               then
                  Good := False;
                  return;
               end if;
               Prior_Item := Namespace (Tree, Candidate);
               if Same_Bytes
                 (Prior_Item.Prefix, Prior_Item.Prefix_Length,
                  Item.Prefix, Item.Prefix_Length)
               then
                  Good := False;
                  return;
               end if;
               Candidate := Prior_Item.Next;
            end loop;
            if Candidate /= Ns then
               Good := False;
               return;
            end if;
            Put (" ");
            if Item.Prefix = System.Null_Address then
               Put ("xmlns");
            else
               Put ("xmlns:");
               Put_Source (Item.Prefix, Item.Prefix_Length);
            end if;
            Put ("=""");
            Emit_Text (Item.Href, Item.Href_Length, True, True, True);
            Put ("""");
            Previous := Ns;
            Last := Ns;
            Ns := Item.Next;
         end loop;
         if Ns /= Null_Namespace
           or else Node (Tree, N).Last_Namespace /= Last
         then
            Good := False;
         end if;
      end Put_Namespaces;

      procedure Put_Properties (N : Node_Ref) is
         P : Node_Ref;
         Item, Child, Other_Item : Node_View;
         Previous, Child_Ref, Child_Previous, Other : Node_Ref := Null_Node;
      begin
         if not Node_Is_Live (N) then
            Good := False;
            return;
         end if;
         P := Node (Tree, N).First_Prop;
         for Step in 1 .. Node_Count (Tree) loop
            exit when P = Null_Node;
            if not Node_Is_Live (P) then
               Good := False;
               return;
            end if;
            Item := Node (Tree, P);
            if Item.State /= Live or else Item.Kind /= Attribute_Node
              or else Item.Parent /= N
              or else Item.Previous /= Previous
            then
               Good := False;
               return;
            end if;
            if Item.Name = System.Null_Address
              or else not Valid_Name (Item.Name, Item.Name_Length, False)
              or else not Name_Namespace_Valid (P, True)
              or else (Item.Namespace = Null_Namespace
                       and then Equal_Bytes
                         (Item.Name, Item.Name_Length, "xmlns"))
            then
               Good := False;
               return;
            end if;
            Other := Item.Next;
            for Other_Step in 1 .. Node_Count (Tree) loop
               exit when Other = Null_Node;
               if not Node_Is_Live (Other) then
                  Good := False;
                  return;
               end if;
               Other_Item := Node (Tree, Other);
               if Other_Item.Kind /= Attribute_Node
                 or else Other_Item.Parent /= N
                 or else Other_Item.Name = System.Null_Address
                 or else not Valid_Name
                   (Other_Item.Name, Other_Item.Name_Length, False)
                 or else not Name_Namespace_Valid (Other, True)
               then
                  Good := False;
                  return;
               end if;
               if Same_Expanded_Name (P, Other) then
                  Good := False;
                  return;
               end if;
               Other := Other_Item.Next;
            end loop;
            if Other /= Null_Node then
               Good := False;
               return;
            end if;
            Put (" ");
            Put_Name (P, True);
            Put ("=""");
            Child_Ref := Item.First_Child;
            Child_Previous := Null_Node;
            for Child_Step in 1 .. Node_Count (Tree) loop
               exit when Child_Ref = Null_Node;
               if not Node_Is_Live (Child_Ref) then
                  Good := False;
                  return;
               end if;
               Child := Node (Tree, Child_Ref);
               if Child.Parent /= P or else Child.Previous /= Child_Previous
                 or else Child.Kind not in Text_Node | CData_Node
               then
                  Good := False;
                  return;
               end if;
               Emit_Text
                 (Child.Content, Child.Content_Length, True, False, True);
               Child_Previous := Child_Ref;
               Child_Ref := Child.Next;
            end loop;
            if Child_Ref /= Null_Node
              or else Item.Last_Child /= Child_Previous
            then
               Good := False;
               return;
            end if;
            Put ("""");
            Previous := P;
            P := Item.Next;
         end loop;
         if P /= Null_Node or else Node (Tree, N).Last_Prop /= Previous then
            Good := False;
         end if;
      end Put_Properties;

      procedure Put_Node (N : Node_Ref) is
         Item : Node_View;
         I : Natural := 0;
         Has_CDATA_End : Boolean;
      begin
         if N = Null_Node
           or else N > Node_Ref (Node_Count (Tree))
           or else N > Node_Ref (Capacity_Of (Tree))
         then
            Good := False;
            return;
         end if;
         Item := Node (Tree, N);
         if Item.State /= Live then
            Good := False;
            return;
         end if;
         case Item.Kind is
            when Element_Node =>
               if (Item.First_Child = Null_Node) /=
                 (Item.Last_Child = Null_Node)
               then
                  Good := False;
                  return;
               end if;
               Put ("<");
               Put_Name (N);
               Put_Namespaces (N);
               Put_Properties (N);
               if Item.First_Child = Null_Node then
                  Put ("/>");
               else
                  Put (">");
               end if;
            when Text_Node =>
               if not Valid_Text (Item.Content, Item.Content_Length) then
                  Good := False;
               else
                  Emit_Text
                    (Item.Content, Item.Content_Length, False, False, True);
               end if;
            when CData_Node =>
               if (Item.Content_Length > 0
                   and then Item.Content = System.Null_Address)
                 or else not Valid_Text (Item.Content, Item.Content_Length)
               then
                  Good := False;
                  return;
               end if;
               if Item.Content_Length = 0 then
                  Put ("<![CDATA[]]>");
               else
                  Put ("<![CDATA[");
                  while Good and then I < Item.Content_Length loop
                     pragma Loop_Variant (Increases => I);
                     Has_CDATA_End :=
                       Item.Content_Length - I > 2
                       and then Native.Byte_At (Item.Content, I) = ']'
                       and then Native.Byte_At (Item.Content, I + 1) = ']'
                       and then Native.Byte_At (Item.Content, I + 2) = '>';
                     if Has_CDATA_End then
                        Put ("]]]]><![CDATA[>");
                        I := I + 3;
                     else
                        Put_Byte (Native.Byte_At (Item.Content, I));
                        I := I + 1;
                     end if;
                  end loop;
                  Put ("]]>");
               end if;
            when Comment_Node =>
               if (Item.Content_Length > 0
                   and then Item.Content = System.Null_Address)
                 or else not Valid_Text (Item.Content, Item.Content_Length)
                 or else Contains_Pair
                   (Item.Content, Item.Content_Length, '-', '-')
                 or else (Item.Content_Length > 0
                       and then Native.Byte_At
                         (Item.Content, Item.Content_Length - 1) = '-')
               then
                  Good := False;
               elsif Item.Content /= System.Null_Address then
                  Put ("<!--");
                  Put_Source (Item.Content, Item.Content_Length);
                  Put ("-->");
               end if;
            when Processing_Instruction_Node =>
               if not Valid_Name (Item.Name, Item.Name_Length, True)
                 or else Equal_ASCII_Case_Insensitive
                   (Item.Name, Item.Name_Length, "xml")
                 or else not Valid_Text (Item.Content, Item.Content_Length)
                 or else Contains_Pair
                   (Item.Content, Item.Content_Length, '?', '>')
               then
                  Good := False;
               else
                  Put ("<?");
                  Put_Source (Item.Name, Item.Name_Length);
                  if Item.Content /= System.Null_Address then
                     Put (" ");
                     Put_Source (Item.Content, Item.Content_Length);
                  end if;
                  Put ("?>");
               end if;
            when others =>
               Good := False;
         end case;
      end Put_Node;

      procedure Pass is
         Current : Node_Ref;
         Parent : Node_Ref;
         Next : Node_Ref;
         Child : Node_Ref;
         Unformatted : Node_Ref := Null_Node;
         Depth : Natural := 0;
         Visited : Natural := 0;
         Ascents : Natural := 0;
         D : Node_View;
         Root_Seen : Boolean := False;

         procedure Put_Indent is
            --  The pinned serializer caps its default indent at 60 bytes.
            Max_Depth : constant := 30;
         begin
            for I in 1 .. Natural'Min (Depth, Max_Depth) loop
               Put ("  ");
            end loop;
         end Put_Indent;
      begin
         if not Node_Is_Live (Document) then
            Good := False;
            return;
         end if;
         D := Node (Tree, Document);
         Current := D.First_Child;
         Put ("<?xml version=""");
         Emit_Text (D.Content, D.Content_Length, True, False, False);
         if not Default_Encoding then
            Put (""" encoding=""");
            Put (Encoding);
         end if;
         Put ("""?>");
         Put_Byte (Character'Val (10));
         if (D.First_Child = Null_Node) /= (D.Last_Child = Null_Node) then
            Good := False;
            return;
         end if;
         while Good and then Current /= Null_Node
           and then Visited < Node_Count (Tree)
         loop
            if not Node_Is_Live (Current) then
               Good := False;
               return;
            end if;
            Parent := Node (Tree, Current).Parent;
            if not Node_Is_Live (Parent)
              or else not Child_Link_Valid (Parent, Current)
            then
               Good := False;
               return;
            end if;
            if Parent = Document then
               if Node (Tree, Current).Kind = Element_Node then
                  if Root_Seen then
                     Good := False;
                     return;
                  end if;
                  Root_Seen := True;
               elsif Node (Tree, Current).Kind not in
                 Comment_Node | Processing_Instruction_Node
               then
                  Good := False;
                  return;
               end if;
            elsif Node (Tree, Current).Kind not in
              Element_Node | Text_Node | CData_Node | Comment_Node |
                Processing_Instruction_Node
            then
               Good := False;
               return;
            end if;
            Visited := Visited + 1;
            if Formatted and then Unformatted = Null_Node then
               Put_Indent;
            end if;
            Put_Node (Current);
            if not Good then
               return;
            end if;
            if Node (Tree, Current).Kind = Element_Node
              and then Node (Tree, Current).First_Child /= Null_Node
            then
               Next := Node (Tree, Current).First_Child;
               if not Child_Link_Valid (Current, Next) then
                  Good := False;
                  return;
               end if;
               if Formatted and then Unformatted = Null_Node then
                  Child := Next;
                  for I in 1 .. Node_Count (Tree) loop
                     exit when Child = Null_Node;
                     if not Node_Is_Live (Child)
                       or else not Child_Link_Valid (Current, Child)
                     then
                        Good := False;
                        return;
                     end if;
                     if Node (Tree, Child).Kind in Text_Node | CData_Node then
                        Unformatted := Current;
                        exit;
                     end if;
                     Child := Node (Tree, Child).Next;
                  end loop;
                  if Child /= Null_Node and then Unformatted /= Current then
                     Good := False;
                     return;
                  end if;
                  if Unformatted = Null_Node then
                     Put_Byte (Character'Val (10));
                  end if;
               end if;
               if Depth >= Node_Count (Tree) then
                  Good := False;
                  return;
               end if;
               Depth := Depth + 1;
               Current := Next;
            else
               loop
                  pragma Loop_Invariant (Node_Is_Live (Current));
                  pragma Loop_Invariant (Node_Is_Live (Parent));
                  pragma Loop_Variant (Increases => Ascents);
                  if Current = Null_Node
                    or else Current > Node_Ref (Node_Count (Tree))
                    or else Current > Node_Ref (Capacity_Of (Tree))
                  then
                     Good := False;
                     return;
                  end if;
                  Parent := Node (Tree, Current).Parent;
                  if Parent = Null_Node or else not Node_Is_Live (Parent) then
                     Good := False;
                     return;
                  end if;
                  Next := Node (Tree, Current).Next;
                  if Parent = Document
                    or else (Formatted and then Unformatted = Null_Node)
                  then
                     Put_Byte (Character'Val (10));
                  end if;
                  if Next /= Null_Node then
                     if not Child_Link_Valid (Parent, Next) then
                        Good := False;
                        return;
                     end if;
                     Current := Next;
                     exit;
                  elsif Parent = Document then
                     Current := Null_Node;
                     exit;
                  end if;
                  if Depth = 0 then
                     Good := False;
                     return;
                  end if;
                  Depth := Depth - 1;
                  if Node (Tree, Parent).Kind = Element_Node
                    and then Node (Tree, Parent).First_Child /= Null_Node
                  then
                     if Formatted and then Unformatted = Null_Node then
                        Put_Indent;
                     end if;
                     Put ("</");
                     Put_Name (Parent);
                     Put (">");
                     if Parent = Unformatted then
                        Unformatted := Null_Node;
                     end if;
                  end if;
                  Current := Parent;
                  if Ascents >= Node_Count (Tree) then
                     Good := False;
                     return;
                  end if;
                  Ascents := Ascents + 1;
               end loop;
            end if;
         end loop;
         if Current /= Null_Node or else Visited > Node_Count (Tree) then
            Good := False;
         end if;
      end Pass;
   begin
      Result := System.Null_Address;
      Length := 0;
      Status := Invalid_Argument;
      if (not Default_Encoding and then not Is_UTF8 (Encoding))
        or else Document = Null_Node
        or else Document > Node_Ref (Capacity_Of (Tree))
        or else Document > Node_Ref (Node_Count (Tree))
        or else Node (Tree, Document).State /= Live
        or else Node (Tree, Document).Kind /= Document_Node
        or else Node (Tree, Document).Content = System.Null_Address
        or else Node (Tree, Document).Content_Length /= 3
        or else not Equal_Bytes
          (Node (Tree, Document).Content,
           Node (Tree, Document).Content_Length, "1.0")
      then
         return;
      end if;
      Pass;
      if not Good then
         Length := 0;
         if Limit_Failure then
            Status := Limit_Exceeded;
         else
            Status := Invalid_Argument;
         end if;
         return;
      end if;
      Length := Cursor;
      if Length > Max_Output_Bytes then
         Length := 0;
         Status := Limit_Exceeded;
         return;
      end if;
      Native.Allocate (Native.Byte_Count (Length) + 1, Base);
      if Base = System.Null_Address then
         Length := 0;
         Status := No_Memory;
         return;
      end if;
      Cursor := 0;
      Capacity := Length;
      Writing := True;
      Good := True;
      Pass;
      if not Good or else Cursor /= Length then
         Native.Free (Base);
         Result := System.Null_Address;
         Length := 0;
         Status := Internal_Error;
         return;
      end if;
      Native.Write_Byte (Base, Length, Character'Val (0));
      Result := Base;
      Status := Created;
   exception
      when others =>
         if Base /= System.Null_Address then
            Native.Free (Base);
         end if;
         Result := System.Null_Address;
         Length := 0;
         Status := Internal_Error;
   end Render;
end XML3_Serialization;
