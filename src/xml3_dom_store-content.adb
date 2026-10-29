with XML3_DOM;
with XML3_DOM_Bridge;
with XML3_DOM_Constructors;
with XML3_DOM_Store.Queries;
with XML3_Text;
with XML3_Text.Buffers;

package body XML3_DOM_Store.Content with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Set_Name
     (S : in out Store; Facade, Name : System.Address;
      Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Registered_Node (S, Facade);
      Target : Node_View;
      Length : XML3_Text.Byte_Count;
      Buffer, Existing : System.Address := System.Null_Address;
      Own : Owner_Ref := Null_Owner;
      Success : Boolean;
      Match_Status : Operation_Status;
   begin
      Status := Created;
      if Facade = System.Null_Address or else Name = System.Null_Address then
         return;
      end if;
      Status := Invalid_Argument;
      if N = Null_Node then
         return;
      end if;
      Target := Node (S.Current.all, N);
      if Target.Kind not in Element_Node | Attribute_Node |
        Processing_Instruction_Node
      then
         Status := Created;
         return;
      end if;
      XML3_Text.Buffers.Measure (Name, Length, Success);
      if not Success then
         Status := Limit_Exceeded;
         return;
      end if;
      if not XML3_Text.Buffers.Valid_Name
        (Name, Length, Target.Kind = Processing_Instruction_Node)
      then
         return;
      end if;
      if Target.Kind = Processing_Instruction_Node and then Length = 3
        and then Native.Byte_At (Name, 0) in 'x' | 'X'
        and then Native.Byte_At (Name, 1) in 'm' | 'M'
        and then Native.Byte_At (Name, 2) in 'l' | 'L'
      then
         return;
      end if;
      if Target.Kind = Attribute_Node
        and then Target.Namespace = Null_Namespace and then Length = 5
        and then Native.Byte_At (Name, 0) = 'x'
        and then Native.Byte_At (Name, 1) = 'm'
        and then Native.Byte_At (Name, 2) = 'l'
        and then Native.Byte_At (Name, 3) = 'n'
        and then Native.Byte_At (Name, 4) = 's'
      then
         return;
      end if;
      if Target.Kind = Attribute_Node and then Target.Parent /= Null_Node then
         XML3_DOM_Store.Queries.Find_Matching_Property
           (S, Node (S.Current.all, Target.Parent).Facade, Facade,
            Existing, Match_Status, Name, Length, Exclude_Source => True);
         if Match_Status /= Created then
            Status := Match_Status;
            return;
         elsif Existing /= System.Null_Address then
            return;
         end if;
      end if;
      if Owner_Count (S.Current.all) = Natural'Last then
         Status := Limit_Exceeded;
         return;
      end if;
      Ensure_Capacity
        (S.Current, Node_Count (S.Current.all), Namespace_Count (S.Current.all),
         Owner_Count (S.Current.all) + 1, Success);
      if not Success then
         Status := No_Memory;
         return;
      end if;
      Native.Allocate (Native.Byte_Count (Length) + 1, Buffer);
      if Buffer = System.Null_Address then
         Status := No_Memory;
         return;
      end if;
      Native.Copy_Bytes (Name, Buffer, Length);
      Native.Write_Byte (Buffer, Length, Character'Val (0));
      Register_Owner (S.Current.all, Buffer, Own, Success);
      if not Success then
         Native.Free (Buffer);
         Status := Internal_Error;
         return;
      end if;
      Set_Node_Projection
        (S.Current.all, N, Buffer, Length, Target.Content, Target.Content_Length,
         Target.Document, Target.Namespace, Target.Ns_Pin, Target.Doc_Pin,
         Target.Content_Pin, Own, Success);
      Release_Reservation (S.Current.all, Own);
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      Status := (if Success then Created else Internal_Error);
   end Set_Name;

   procedure New_Doc_Content
     (S : in out Store; Doc : System.Address; Kind : Node_Kind;
      Name, Content : String; Has_Content : Boolean; Result : out System.Address;
      Status : out Operation_Status; Ns : System.Address := System.Null_Address;
      Content_Source : System.Address := System.Null_Address;
      Source_Length : Natural := 0)
   is
      D : Node_Ref := Find_Registered_Node (S, Doc);
      N : Node_Ref;
      Facade, Ignored_Ns : System.Address := System.Null_Address;
      Changed : Boolean;
      Cleanup_Status : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Kind not in Element_Node | Attribute_Node | Text_Node | CData_Node |
        Comment_Node | Processing_Instruction_Node
        or else (Kind in Element_Node | Attribute_Node and then Has_Content)
        or else (Kind = Attribute_Node and then
          (Ns /= System.Null_Address or else (for some C of Name => C = ':')))
      then
         return;
      end if;
      if Doc /= System.Null_Address
        and then (D = Null_Node
          or else Node (S.Current.all, D).Kind /= Document_Node)
      then
         return;
      end if;
      Construct
        (S, Kind, Name, Content, Has_Content, Ns,
         Facade, Ignored_Ns, Status, Content_Source, Source_Length);
      if Status /= Created then
         return;
      end if;
      if Doc /= System.Null_Address then
         D := Find_Registered_Node (S, Doc);
         N := Find_Node (S, Facade);
         if D = Null_Node or else N = Null_Node
           or else Node (S.Current.all, D).Kind /= Document_Node
         then
            Status := Internal_Error;
         else
            declare
               Item : constant Node_View := Node (S.Current.all, N);
            begin
               Set_Node_Projection
                 (S.Current.all, N, Item.Name, Item.Name_Length,
                  Item.Content, Item.Content_Length, D, Item.Namespace,
                  Item.Ns_Pin, Node (S.Current.all, D).Owner,
                  Item.Content_Pin, Item.Name_Pin, Changed);
            end;
            XML3_DOM_Bridge.Synchronize (S.Current.all);
            if not Changed then
               Status := Limit_Exceeded;
            end if;
         end if;
      end if;
      if Status = Created then
         Result := Facade;
      else
         Release
           (S, Facade, (if Kind = Attribute_Node then Plain_Attribute
                        else Content_Node), False, Cleanup_Status);
         if Cleanup_Status /= Created then
            Status := Internal_Error;
         end if;
      end if;
   end New_Doc_Content;

   procedure New_Doc_Content_Bytes
     (S : in out Store; Doc : System.Address; Kind : Node_Kind;
      Name : String; Content : System.Address; Length : Integer;
      Terminated : Boolean; Result : out System.Address;
      Status : out Operation_Status)
   is
      D : constant Node_Ref := Find_Registered_Node (S, Doc);
      Span : XML3_Text.Byte_Count := 0;
      Found : Boolean;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Kind not in Text_Node | CData_Node | Comment_Node |
        Processing_Instruction_Node
        or else (Doc /= System.Null_Address and then
          (D = Null_Node or else Node (S.Current.all, D).Kind /= Document_Node))
      then
         return;
      end if;
      if Content /= System.Null_Address then
         if Terminated then
            XML3_Text.Buffers.Measure (Content, Span, Found);
            if not Found then
               return;
            end if;
         else
            if Length not in 0 .. XML3_Text.Max_Bytes then
               return;
            end if;
            XML3_Text.Buffers.Measure_Byte_Prefix
              (Content, XML3_Text.Byte_Count (Length), Span);
         end if;
      end if;
      New_Doc_Content
        (S, Doc, Kind, Name, "", Content /= System.Null_Address, Result, Status,
         Content_Source => Content, Source_Length => Span);
   end New_Doc_Content_Bytes;

   procedure Parse_Content_List
     (S : in out Store; Doc : System.Address; Content : String;
      Result : out System.Address; Status : out Operation_Status)
   is
      Decoded : String (1 .. Content'Length);
      Length : XML3_Text.Byte_Count;
      Valid : Boolean;
      D : Node_Ref;
   begin
      Result := System.Null_Address;
      Status := Created;
      if Content'Length = 0 then
         return;
      end if;
      Status := Invalid_Argument;
      D := Find_Registered_Node (S, Doc);
      if Doc /= System.Null_Address
        and then (D = Null_Node
          or else Node (S.Current.all, D).Kind /= Document_Node)
      then
         return;
      end if;
      if Content'First /= 1 or else Content'Last > XML3_Text.Max_Bytes then
         Status := Limit_Exceeded;
         return;
      end if;
      XML3_Text.Decode
        (Content, False, True, Decoded, Length, Valid,
         Normalize_Line_Endings => False);
      if not Valid then
         return;
      end if;
      New_Doc_Content
        (S, Doc, Text_Node, "text", Decoded (1 .. Integer (Length)), True,
         Result, Status);
   end Parse_Content_List;

   procedure New_Doc_Node
     (S : in out Store; Doc, Ns : System.Address;
      Name, Content : String; Raw_Content, Has_Content : Boolean;
      Result : out System.Address;
      Status : out Operation_Status; Attribute_Mode : Boolean := False)
   is
      Element, Text, Ignored_Ns : System.Address := System.Null_Address;
      Cleanup_Status : Operation_Status;
      Decoded : String (1 .. Content'Length) := (others => Character'Val (0));
      Decoded_Length : XML3_Text.Byte_Count := 0;
      Decoded_Valid : Boolean;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if Has_Content and then Raw_Content then
         if Content'Length > XML3_Text.Max_Bytes then
            Status := Limit_Exceeded;
            return;
         end if;
         Decoded := Content;
         Decoded_Length := Content'Length;
      elsif Has_Content and then Content'Length > 0 then
         if Content'First /= 1 or else Content'Last > XML3_Text.Max_Bytes then
            Status := Limit_Exceeded;
            return;
         end if;
         XML3_Text.Decode
           (Content, False, True, Decoded, Decoded_Length, Decoded_Valid,
            Normalize_Line_Endings => False);
         if not Decoded_Valid then
            return;
         end if;
      end if;
      New_Doc_Content
        (S, Doc, (if Attribute_Mode then Attribute_Node else Element_Node),
         Name, "", False, Element, Status, Ns);
      if Status /= Created then
         return;
      end if;
      if Decoded_Length > 0 or else (Raw_Content and then Has_Content) then
         Construct
           (S, Text_Node, "text", Decoded (1 .. Integer (Decoded_Length)),
            True, System.Null_Address, Text, Ignored_Ns, Status);
         if Status = Created then
            Attach (S, Element, Text, False, Status);
            if Status /= Created then
               Release (S, Text, Content_Node, False, Cleanup_Status);
               if Cleanup_Status /= Created then
                  Status := Internal_Error;
               end if;
            end if;
         end if;
      end if;
      if Status = Created then
         Result := Element;
      else
         Release
           (S, Element, (if Attribute_Mode then Plain_Attribute
                         else Content_Node), False, Cleanup_Status);
         if Cleanup_Status /= Created then
            Status := Internal_Error;
         end if;
      end if;
   end New_Doc_Node;

   procedure New_Child
     (S : in out Store; Parent, Ns : System.Address;
      Name, Content : String; Raw_Content, Has_Content : Boolean;
      Result : out System.Address;
      Status : out Operation_Status)
   is
      P : constant Node_Ref := Find_Node (S, Parent);
      Selected_Ns : System.Address := Ns;
      Element : System.Address := System.Null_Address;
      Cleanup_Status : Operation_Status;
   begin
      Result := System.Null_Address;
      Status := Invalid_Argument;
      if P = Null_Node or else Node (S.Current.all, P).Kind not in
        Element_Node | Document_Node
      then
         return;
      end if;
      if Selected_Ns = System.Null_Address
        and then Node (S.Current.all, P).Kind = Element_Node
        and then Node (S.Current.all, P).Namespace /= Null_Namespace
      then
         Selected_Ns := Namespace
           (S.Current.all, Node (S.Current.all, P).Namespace).Facade;
      end if;
      New_Doc_Node
        (S, System.Null_Address, Selected_Ns, Name, Content,
         Raw_Content, Has_Content, Element, Status);
      if Status /= Created then
         return;
      end if;
      Attach (S, Parent, Element, False, Status);
      if Status = Created then
         Result := Element;
      else
         Release (S, Element, Content_Node, False, Cleanup_Status);
         if Cleanup_Status /= Created then
            Status := Internal_Error;
         end if;
      end if;
   end New_Child;

   procedure Replace_Content
     (S : in out Store; N : Node_Ref; Value : String;
      Append_Mode, Has_Content : Boolean; Status : out Operation_Status)
     with Pre => S.Current /= null
       and then Valid (S.Current.all)
       and then Can_Edit (S.Current.all)
       and then not Projection_Required (S.Current.all)
       and then Facades_Present (S.Current.all)
       and then N in 1 .. Node_Ref (Node_Count (S.Current.all))
       and then Node (S.Current.all, N).State = Live,
     Post => S.Current /= null
       and then Valid (S.Current.all)
       and then Can_Edit (S.Current.all)
       and then not Projection_Required (S.Current.all)
       and then Facades_Present (S.Current.all)
       and then Node_Count (S.Current.all) =
         Node_Count (S.Current.all)'Old
       and then Namespace_Count (S.Current.all) =
         Namespace_Count (S.Current.all)'Old
       and then (for all I in Node_Ref range
         1 .. Node_Ref (Node_Count (S.Current.all)) =>
           (if I /= N
             and then (Node (S.Current.all'Old, I).State = Live
                       or else Node (S.Current.all, I).State = Live)
           then
              Node (S.Current.all, I) = Node (S.Current.all'Old, I)))
       and then (if Status /= Created then
         Node (S.Current.all, N) = Node (S.Current.all'Old, N)
       else
         Node (S.Current.all, N) =
           (Node (S.Current.all'Old, N) with delta
              Content => Node (S.Current.all, N).Content,
              Content_Length => Node (S.Current.all, N).Content_Length,
              Content_Pin => Node (S.Current.all, N).Content_Pin));

   procedure Replace_Content
     (S : in out Store; N : Node_Ref; Value : String;
      Append_Mode, Has_Content : Boolean; Status : out Operation_Status)
   is
      Target : constant Node_View := Node (S.Current.all, N);
      Length : Natural;
      Buffer, Suffix_Address : System.Address := System.Null_Address;
      Own : Owner_Ref := Null_Owner;
      Success : Boolean;
   begin
      Status := Limit_Exceeded;
      if Append_Mode
        and then (Value'Length > Natural'Last - Target.Content_Length
          or else Target.Content_Length + Value'Length > Integer'Last - 1)
      then
         return;
      end if;
      if Has_Content and then not Append_Mode
        and then Value'Length > Integer'Last - 1
      then
         return;
      end if;
      if Has_Content and then Owner_Count (S.Current.all) = Natural'Last
      then
         return;
      end if;
      if Target.Content_Length > 0
        and then Target.Content = System.Null_Address
      then
         Status := Internal_Error;
         return;
      end if;

      Length := (if Append_Mode then Target.Content_Length else Natural (0))
        + (if Has_Content then Value'Length else Natural (0));
      if Has_Content then
         Ensure_Capacity
           (S.Current, Node_Count (S.Current.all),
            Namespace_Count (S.Current.all), Owner_Count (S.Current.all) + 1,
            Success);
         if not Success then
            Status := No_Memory;
            return;
         end if;
      end if;
      if Has_Content then
         Native.Allocate (Native.Byte_Count (Length) + 1, Buffer);
         if Buffer = System.Null_Address then
            Status := No_Memory;
            return;
         end if;
         Suffix_Address :=
           Native.Offset
             (Buffer, Native.Byte_Count
                (if Append_Mode then Target.Content_Length else Natural (0)));
         if Suffix_Address = System.Null_Address then
            Native.Free (Buffer);
            Status := Internal_Error;
            return;
         end if;
         if Append_Mode then
            Native.Copy_Bytes (Target.Content, Buffer, Target.Content_Length);
         end if;
         Native.Write_String (Suffix_Address, 0, Value);
         Native.Write_Byte (Buffer, Length, Character'Val (0));
         Register_Owner (S.Current.all, Buffer, Own, Success);
         if not Success then
            Native.Free (Buffer);
            Status := Internal_Error;
            return;
         end if;
      end if;
      Set_Node_Projection
        (S.Current.all, N, Target.Name, Target.Name_Length,
         Buffer, Length, Target.Document, Target.Namespace,
         Target.Ns_Pin, Target.Doc_Pin, Own, Target.Name_Pin, Success);
      if Has_Content then
         Release_Reservation (S.Current.all, Own);
      end if;
      XML3_DOM_Bridge.Synchronize (S.Current.all);
      if Success then
         Status := Created;
      else
         Status := Internal_Error;
      end if;
   end Replace_Content;

   procedure Append
      (S : in out Store; Facade : System.Address; Suffix : String;
      Status : out Operation_Status; Has_Input : Boolean := False;
      Text_Only : Boolean := False)
   is
      N : constant Node_Ref := Find_Node (S, Facade);
      Tail : Node_Ref;
      New_Node : Node_Ref;
      Ignored_Namespace : Namespace_Ref;
      Attached : Boolean;
      Created_Status : Operation_Status;
      Cleanup_Status : Operation_Status;
   begin
      Status := Invalid_Argument;
      if N = Null_Node then
         return;
      end if;
      if Text_Only and then Node (S.Current.all, N).Kind not in
        Text_Node | CData_Node | Comment_Node | Processing_Instruction_Node
      then
         return;
      end if;
      if Suffix'Length = 0 and then not Has_Input then
         Status := Created;
         return;
      end if;

      case Node (S.Current.all, N).Kind is
         when Text_Node | CData_Node | Comment_Node
           | Processing_Instruction_Node =>
            Replace_Content (S, N, Suffix, True, True, Status);

         when Element_Node | Attribute_Node =>
            if Node (S.Current.all, N).Kind = Attribute_Node
              and then not Text_Attribute_Content (S.Current.all, N)
            then
               return;
            end if;
            Tail := Node (S.Current.all, N).Last_Child;
            if Tail /= Null_Node then
               if Tail > Node_Ref (Node_Count (S.Current.all))
                 or else Node (S.Current.all, Tail).State /= Live
                 or else Node (S.Current.all, Tail).Parent /= N
               then
                  Status := Internal_Error;
                  return;
               end if;
               if Node (S.Current.all, Tail).Kind = Text_Node then
                  Replace_Content (S, Tail, Suffix, True, True, Status);
                  return;
               end if;
            end if;

            Create_Node
              (S.Current, Text_Node, "text", Suffix, True, Null_Namespace,
               New_Node, Ignored_Namespace, Created_Status);
            if Created_Status /= Created then
               Status := Created_Status;
               return;
            end if;
            Attach_Child (S.Current.all, N, New_Node, Attached);
            if not Attached then
               XML3_DOM_Bridge.Synchronize (S.Current.all);
               XML3_DOM_Store.Release
                 (S, Node (S.Current.all, New_Node).Facade, Content_Node,
                  False, Cleanup_Status);
               if Cleanup_Status /= Created then
                  Status := Internal_Error;
               else
                  Status := Invalid_Argument;
               end if;
               return;
            end if;
            XML3_DOM_Bridge.Synchronize (S.Current.all);
            Status := Created;

         when Document_Node =>
            Status := Created;
      end case;
   end Append;

   procedure Set
     (S : in out Store; Facade : System.Address; Content : String;
      Has_Content : Boolean; Status : out Operation_Status)
   is
      N : constant Node_Ref := Find_Node (S, Facade);
      New_Node : Node_Ref;
      Ignored_Namespace : Namespace_Ref;
      Created_Status, Cleanup_Status : Operation_Status;
      Attached, Decoded_Valid : Boolean;
      Decoded_Length : XML3_Text.Byte_Count;
      Decoded : String (1 .. Content'Length) :=
        (others => Character'Val (0));
   begin
      Status := Invalid_Argument;
      if N = Null_Node then
         return;
      end if;
      if Node (S.Current.all, N).Kind = Document_Node then
         Status := Created;
         return;
      end if;
      case Node (S.Current.all, N).Kind is
         when Text_Node | CData_Node | Comment_Node
           | Processing_Instruction_Node =>
            Replace_Content (S, N, Content, False, Has_Content, Status);
         when Element_Node | Attribute_Node =>
            if Has_Content and then Content'Length > 0 then
               if Content'First /= 1
                 or else Content'Last > XML3_Text.Max_Bytes
               then
                  Status := Limit_Exceeded;
                  return;
               end if;
               XML3_Text.Decode
                 (Content, False, True, Decoded, Decoded_Length,
                  Decoded_Valid, False);
               if not Decoded_Valid then
                  return;
               end if;
            else
               Decoded_Length := 0;
            end if;
            New_Node := Null_Node;
            if Decoded_Length > 0 then
               Create_Node
                 (S.Current, Text_Node, "text",
                  Decoded (1 .. Integer (Decoded_Length)), True,
                  Null_Namespace, New_Node, Ignored_Namespace,
                  Created_Status);
               if Created_Status /= Created then
                  Status := Created_Status;
                  return;
               end if;
               Attach_Child (S.Current.all, N, New_Node, Attached);
               if not Attached then
                  XML3_DOM_Bridge.Synchronize (S.Current.all);
                  XML3_DOM_Store.Release
                    (S, Node (S.Current.all, New_Node).Facade,
                     Content_Node, False, Cleanup_Status);
                  Status := (if Cleanup_Status = Created
                             then Invalid_Argument else Internal_Error);
                  return;
               end if;
            end if;
            if Node (S.Current.all, N).Kind = Attribute_Node then
               Retire_Attribute_Children (S.Current.all, N, New_Node);
            else
               XML3_DOM.Retire_Element_Children
                 (S.Current.all, N, New_Node);
            end if;
            XML3_DOM_Bridge.Synchronize (S.Current.all);
            Status := Created;
         when Document_Node =>
            Status := Created;
      end case;
   end Set;
end XML3_DOM_Store.Content;
