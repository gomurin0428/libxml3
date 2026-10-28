with XML3_DOM;
with XML3_DOM_Bridge;
with XML3_DOM_Constructors;
with XML3_Text;

package body XML3_DOM_Store.Content with SPARK_Mode is
   use XML3_DOM;
   use XML3_DOM_Constructors;
   package Native renames XML3_Native_Memory;
   use type Native.Byte_Count;
   pragma Unevaluated_Use_Of_Old (Allow);

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
         Target.Ns_Pin, Target.Doc_Pin, Own, Success);
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
      Status : out Operation_Status)
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
      if Suffix'Length = 0 then
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
