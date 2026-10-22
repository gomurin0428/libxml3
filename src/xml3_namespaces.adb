with XML3_Text;

package body XML3_Namespaces with SPARK_Mode is
   procedure Resolve
     (Input : String; Nodes : Node_Array; Count : Node_Id;
      Names : out Name_Array; Scratch_A, Scratch_B : in out String;
      Status : out Parse_Status;
      Diagnostic : out Diagnostic_Info)
   is
      function Input_Valid return Boolean is
        (Input'First = 1 and then Input'Length <= Offset'Last
         and then Nodes'First = 1
         and then Nodes'Last in 1 .. Max_Nodes
         and then Count <= Nodes'Last
         and then (for all K in 1 .. Count =>
           Nodes (K).Parent < K
           and then Nodes (K).Name_Last <= Input'Length
           and then Nodes (K).Value_Last <= Input'Length
           and then Nodes (K).Name_First <= Nodes (K).Name_Last + 1
           and then Nodes (K).Value_First <= Nodes (K).Value_Last + 1))
        with Ghost;

      function Names_Valid (Last : Node_Id) return Boolean is
        (Names'First = 1 and then Nodes'First = 1
         and then Count <= Nodes'Last and then Last <= Count
         and then Last <= Names'Last
         and then (for all K in 1 .. Last =>
           Names (K).Local_First in Nodes (K).Name_First .. Nodes (K).Name_Last + 1
           and Names (K).Prefix_Last in Nodes (K).Name_First - 1 .. Nodes (K).Name_Last
           and (Names (K).Binding <= Count or Names (K).Binding = Implicit_XML)))
        with Ghost;

      procedure Decode_Value
        (Id : Node_Id; Buffer : in out String;
         Length : out XML3_Text.Byte_Count; Valid : out Boolean)
        with Pre => Id in 1 .. Count and Input_Valid
          and Buffer'First = 1 and Buffer'Length = Input'Length,
          Post => Length <= Buffer'Length
      is
      begin
         XML3_Text.Decode
           (Input (Nodes (Id).Value_First .. Nodes (Id).Value_Last),
            True, True,
            Buffer
              (1 .. Nodes (Id).Value_Last - Nodes (Id).Value_First + 1),
            Length, Valid);
      end Decode_Value;

      procedure Value_Matches
        (Id : Node_Id; Value : String; Matches : out Boolean;
         Buffer : in out String)
        with Pre => Id in 1 .. Count and Input_Valid
          and Buffer'First = 1 and Buffer'Length = Input'Length
      is
         Length : XML3_Text.Byte_Count;
         Valid : Boolean;
      begin
         Decode_Value (Id, Buffer, Length, Valid);
         Matches := Valid and then Length = Value'Length
           and then Buffer (1 .. Length) = Value;
      end Value_Matches;

      procedure Same_Namespace
        (Left, Right : Binding_Id; Same : out Boolean;
         Left_Buffer, Right_Buffer : in out String)
        with Pre => Input_Valid and (Left <= Count or Left = Implicit_XML)
          and (Right <= Count or Right = Implicit_XML)
          and Left_Buffer'First = 1 and Left_Buffer'Length = Input'Length
          and Right_Buffer'First = 1 and Right_Buffer'Length = Input'Length
      is
         L_Length, R_Length : XML3_Text.Byte_Count;
         L_Valid, R_Valid : Boolean;
      begin
         if Left = Right then
            Same := True;
         elsif Left = 0 or Right = 0 then
            Same := False;
         elsif Left = Implicit_XML then
            Value_Matches (Right, XML_URI, Same, Right_Buffer);
         elsif Right = Implicit_XML then
            Value_Matches (Left, XML_URI, Same, Left_Buffer);
         else
            Decode_Value (Left, Left_Buffer, L_Length, L_Valid);
            Decode_Value (Right, Right_Buffer, R_Length, R_Valid);
            Same := L_Valid and then R_Valid and then L_Length = R_Length
              and then Left_Buffer (1 .. L_Length) = Right_Buffer (1 .. R_Length);
         end if;
      end Same_Namespace;

      function Find_Binding (Owner : Node_Id; Prefix : String) return Binding_Id
        with Pre => Owner <= Count and Input_Valid and Names_Valid (Count),
          Post => Find_Binding'Result <= Count or Find_Binding'Result = Implicit_XML
      is
         Current : Node_Id := Owner;
      begin
         if Prefix = "xml" then
            return Implicit_XML;
         end if;
         while Current /= 0 loop
            pragma Loop_Invariant (Current <= Count);
            pragma Loop_Invariant (Current in 1 .. Count);
            pragma Loop_Variant (Decreases => Current);
            declare
               J : Natural := Current + 1;
            begin
               while J <= Count
                 and then Nodes (J).Kind = Attribute_Node
                 and then Nodes (J).Parent = Current
               loop
                  pragma Loop_Invariant (J in Current + 1 .. Count + 1);
                  pragma Loop_Variant (Increases => J);
                  if Names (J).Declaration then
                     if Names (J).Prefix_Last < Nodes (J).Name_First then
                        if Prefix'Length = 0 then
                           return J;
                        end if;
                     elsif Input
                       (Names (J).Local_First .. Nodes (J).Name_Last) = Prefix
                     then
                        return J;
                     end if;
                  end if;
                  J := J + 1;
               end loop;
            end;
            Current := Nodes (Current).Parent;
         end loop;
         return 0;
      end Find_Binding;
   begin
      Names := (others => (others => <>));
      Status := Success;
      Diagnostic := (Domain => 3, Code => 0, Level => 2,
                     Byte_Position => 1, Int1 => 0, Int2 => 0);
      for K in 1 .. Count loop
         Names (K).Local_First := Nodes (K).Name_First;
         Names (K).Prefix_Last := Nodes (K).Name_First - 1;
         pragma Loop_Invariant (Names_Valid (K));
      end loop;

      for K in 1 .. Count loop
         pragma Loop_Invariant (Names_Valid (Count));
         if Nodes (K).Kind = Element_Node or Nodes (K).Kind = Attribute_Node then
            if Nodes (K).Name_First > Nodes (K).Name_Last or else
              XML3_Text.Name_Width (Input, Nodes (K).Name_First, True) = 0
            then
               Status := Malformed;
               Diagnostic :=
                 (Domain => 3, Code => 202, Level => 2,
                  Byte_Position => Nodes (K).Name_Last + 1,
                  Int1 => 0, Int2 => 0);
               return;
            end if;
            for P in Nodes (K).Name_First .. Nodes (K).Name_Last loop
               pragma Loop_Invariant (Names_Valid (Count));
               if Input (P) = ':' then
                  if Names (K).Prefix_Last >= Nodes (K).Name_First
                    or else P = Nodes (K).Name_First or else P = Nodes (K).Name_Last
                    or else XML3_Text.Name_Width (Input, P + 1, True) = 0
                  then
                     Status := Malformed;
                     Diagnostic :=
                       (Domain => 3, Code => 202, Level => 2,
                        Byte_Position => Nodes (K).Name_Last + 1,
                        Int1 => 0, Int2 => 0);
                     return;
                  end if;
                  Names (K).Prefix_Last := P - 1;
                  Names (K).Local_First := P + 1;
               end if;
            end loop;
            Names (K).Declaration := Nodes (K).Kind = Attribute_Node and then
              (Input (Nodes (K).Name_First .. Nodes (K).Name_Last) = "xmlns" or else
               Input (Nodes (K).Name_First .. Names (K).Prefix_Last) = "xmlns");
         end if;
      end loop;

      for K in 1 .. Count loop
         pragma Loop_Invariant (Names_Valid (Count));
         if Names (K).Declaration then
            declare
               Length : XML3_Text.Byte_Count;
               Valid : Boolean;
            begin
               Decode_Value (K, Scratch_A, Length, Valid);
               if not Valid
                 or else
                   (Names (K).Prefix_Last >= Nodes (K).Name_First
                    and then Input
                      (Names (K).Local_First .. Nodes (K).Name_Last) = "xmlns")
                 or else (Length = XMLNS_URI'Length
                          and then Scratch_A (1 .. Length) = XMLNS_URI)
                 or else
                   (Names (K).Prefix_Last >= Nodes (K).Name_First
                    and then Input
                      (Names (K).Local_First .. Nodes (K).Name_Last) = "xml"
                    and then
                      (Length /= XML_URI'Length
                       or else Scratch_A (1 .. Length) /= XML_URI))
                 or else
                   (not (Names (K).Prefix_Last >= Nodes (K).Name_First
                         and then Input
                           (Names (K).Local_First .. Nodes (K).Name_Last) = "xml")
                    and then Length = XML_URI'Length
                    and then Scratch_A (1 .. Length) = XML_URI)
                 or else
                   (Names (K).Prefix_Last >= Nodes (K).Name_First
                    and then Length = 0)
               then
                  Status := Malformed;
                  Diagnostic :=
                    (Domain => 3,
                     Code => 200,
                     Level => 2,
                     Byte_Position =>
                       (if Nodes (K).Value_Last < Input'Length
                        then Nodes (K).Value_Last + 2 else Input'Length + 1),
                     Int1 => 0, Int2 => 0);
                  return;
               end if;
               if Names (K).Prefix_Last >= Nodes (K).Name_First
                 and then Input
                   (Names (K).Local_First .. Nodes (K).Name_Last) = "xml"
               then
                  Names (K).Binding := Implicit_XML;
               end if;
            end;
         end if;
      end loop;

      for K in 1 .. Count loop
         pragma Loop_Invariant (Names_Valid (Count));
         if not Names (K).Declaration and then
           (Nodes (K).Kind = Element_Node or Nodes (K).Kind = Attribute_Node)
         then
            declare
               Prefix_Length : constant Natural :=
                 Names (K).Prefix_Last - Nodes (K).Name_First + 1;
               Owner : constant Node_Id :=
                 (if Nodes (K).Kind = Element_Node then K else Nodes (K).Parent);
               Binding : Binding_Id := 0;
               Empty_Uri : Boolean;
            begin
               if Nodes (K).Kind = Element_Node or else Prefix_Length /= 0 then
                  Binding := Find_Binding
                    (Owner,
                     Input (Nodes (K).Name_First .. Names (K).Prefix_Last));
               end if;
               if Prefix_Length /= 0 and then Binding = 0 then
                  Status := Malformed;
                  Diagnostic :=
                    (Domain => 3, Code => 201, Level => 2,
                     Byte_Position =>
                       (if Nodes (K).Kind = Element_Node
                        then Nodes (K).Name_Last + 1
                        elsif Nodes (K).Value_Last < Input'Length
                        then Nodes (K).Value_Last + 2 else Input'Length + 1),
                     Int1 => 0, Int2 => 0);
                  return;
               end if;
               if Binding in 1 .. Count then
                  Value_Matches (Binding, "", Empty_Uri, Scratch_A);
                  if Empty_Uri then
                     Binding := 0;
                  end if;
               end if;
               Names (K).Binding := Binding;
            end;
         end if;
      end loop;

      for K in 1 .. Count loop
         if Nodes (K).Kind = Attribute_Node and then not Names (K).Declaration then
            for J in Nodes (K).Parent + 1 .. K - 1 loop
               if Nodes (J).Kind = Attribute_Node and then not Names (J).Declaration
                 and then Nodes (J).Parent = Nodes (K).Parent
                 and then Input (Names (J).Local_First .. Nodes (J).Name_Last) =
                   Input (Names (K).Local_First .. Nodes (K).Name_Last)
               then
                  declare
                     Same : Boolean;
                  begin
                     Same_Namespace
                       (Names (J).Binding, Names (K).Binding, Same,
                        Scratch_A, Scratch_B);
                    if Same then
                       Status := Malformed;
                        Diagnostic :=
                          (Domain => 3, Code => 203, Level => 2,
                           Byte_Position =>
                             (if Nodes (K).Value_Last < Input'Length
                              then Nodes (K).Value_Last + 2
                              else Input'Length + 1),
                           Int1 => 0, Int2 => 0);
                        return;
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end loop;
   end Resolve;
end XML3_Namespaces;
