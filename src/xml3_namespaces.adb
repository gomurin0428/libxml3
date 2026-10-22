with XML3_Text;

package body XML3_Namespaces with SPARK_Mode is
   procedure Resolve
     (Input : String; Nodes : Node_Array; Count : Node_Id;
      Names : out Name_Array; Status : out Parse_Status)
   is
      function Input_Valid return Boolean is
        (Input'First = 1 and Input'Length <= Offset'Last
         and (for all K in 1 .. Count =>
           Nodes (K).Parent < K
           and Nodes (K).Name_Last <= Input'Length
           and Nodes (K).Value_Last <= Input'Length
           and Nodes (K).Name_First <= Nodes (K).Name_Last + 1
           and Nodes (K).Value_First <= Nodes (K).Value_Last + 1))
        with Ghost;

      function Names_Valid (Last : Node_Id) return Boolean is
        (for all K in 1 .. Last =>
          Names (K).Local_First in Nodes (K).Name_First .. Nodes (K).Name_Last + 1
          and Names (K).Prefix_Last in Nodes (K).Name_First - 1 .. Nodes (K).Name_Last
          and (Names (K).Binding <= Count or Names (K).Binding = Implicit_XML))
        with Ghost;

      function Value_Matches (Id : Node_Id; Value : String) return Boolean
        with Pre => Id in 1 .. Count and Input_Valid
      is
         Raw : constant String (1 .. Nodes (Id).Value_Last - Nodes (Id).Value_First + 1) :=
           Input (Nodes (Id).Value_First .. Nodes (Id).Value_Last);
         Decoded : String (1 .. Raw'Length);
         Length : XML3_Text.Byte_Count;
         Valid : Boolean;
      begin
         XML3_Text.Decode (Raw, True, True, Decoded, Length, Valid);
         return Valid and then Decoded (1 .. Length) = Value;
      end Value_Matches;

      function Same_Namespace (Left, Right : Binding_Id) return Boolean
        with Pre => Input_Valid and (Left <= Count or Left = Implicit_XML)
          and (Right <= Count or Right = Implicit_XML)
      is
      begin
         if Left = Right then
            return True;
         elsif Left = 0 or Right = 0 then
            return False;
         elsif Left = Implicit_XML then
            return Value_Matches (Right, XML_URI);
         elsif Right = Implicit_XML then
            return Value_Matches (Left, XML_URI);
         else
            declare
               L_Raw : constant String (1 .. Nodes (Left).Value_Last - Nodes (Left).Value_First + 1) :=
                 Input (Nodes (Left).Value_First .. Nodes (Left).Value_Last);
               R_Raw : constant String (1 .. Nodes (Right).Value_Last - Nodes (Right).Value_First + 1) :=
                 Input (Nodes (Right).Value_First .. Nodes (Right).Value_Last);
               L_Value : String (1 .. L_Raw'Length);
               R_Value : String (1 .. R_Raw'Length);
               L_Length, R_Length : XML3_Text.Byte_Count;
               L_Valid, R_Valid : Boolean;
            begin
               XML3_Text.Decode (L_Raw, True, True, L_Value, L_Length, L_Valid);
               XML3_Text.Decode (R_Raw, True, True, R_Value, R_Length, R_Valid);
               return L_Valid and then R_Valid
                 and then L_Value (1 .. L_Length) = R_Value (1 .. R_Length);
            end;
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
            pragma Loop_Variant (Decreases => Current);
            for J in 1 .. Count loop
               if Names (J).Declaration and then Nodes (J).Parent = Current then
                  if Names (J).Prefix_Last < Nodes (J).Name_First then
                     if Prefix'Length = 0 then
                        return J;
                     end if;
                  elsif Input (Names (J).Local_First .. Nodes (J).Name_Last) = Prefix then
                     return J;
                  end if;
               end if;
            end loop;
            Current := Nodes (Current).Parent;
         end loop;
         return 0;
      end Find_Binding;
   begin
      Names := (others => (others => <>));
      Status := Success;
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
               Prefix : constant String :=
                 (if Names (K).Prefix_Last < Nodes (K).Name_First then ""
                  else Input (Names (K).Local_First .. Nodes (K).Name_Last));
               Raw : constant String (1 .. Nodes (K).Value_Last - Nodes (K).Value_First + 1) :=
                 Input (Nodes (K).Value_First .. Nodes (K).Value_Last);
               Value : String (1 .. Raw'Length);
               Length : XML3_Text.Byte_Count;
               Valid : Boolean;
            begin
               XML3_Text.Decode (Raw, True, True, Value, Length, Valid);
               if not Valid or else Prefix = "xmlns"
                 or else Value (1 .. Length) = XMLNS_URI
                 or else (Prefix = "xml" and then Value (1 .. Length) /= XML_URI)
                 or else (Prefix /= "xml" and then Value (1 .. Length) = XML_URI)
                 or else (Prefix'Length /= 0 and then Length = 0)
               then
                  Status := Malformed;
                  return;
               end if;
               if Prefix = "xml" then
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
               Prefix : constant String := Input (Nodes (K).Name_First .. Names (K).Prefix_Last);
               Owner : constant Node_Id :=
                 (if Nodes (K).Kind = Element_Node then K else Nodes (K).Parent);
               Binding : Binding_Id := 0;
            begin
               if Nodes (K).Kind = Element_Node or else Prefix'Length /= 0 then
                  Binding := Find_Binding (Owner, Prefix);
               end if;
               if Prefix'Length /= 0 and then Binding = 0 then
                  Status := Malformed;
                  return;
               end if;
               if Binding in 1 .. Count and then Value_Matches (Binding, "") then
                  Binding := 0;
               end if;
               Names (K).Binding := Binding;
            end;
         end if;
      end loop;

      for K in 1 .. Count loop
         if Nodes (K).Kind = Attribute_Node and then not Names (K).Declaration then
            for J in 1 .. K - 1 loop
               if Nodes (J).Kind = Attribute_Node and then not Names (J).Declaration
                 and then Nodes (J).Parent = Nodes (K).Parent
                 and then Input (Names (J).Local_First .. Nodes (J).Name_Last) =
                   Input (Names (K).Local_First .. Nodes (K).Name_Last)
                 and then Same_Namespace (Names (J).Binding, Names (K).Binding)
               then
                  Status := Malformed;
                  return;
               end if;
            end loop;
         end if;
      end loop;
   end Resolve;
end XML3_Namespaces;
