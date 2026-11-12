package body XML3_Declarations with SPARK_Mode is

   function Space (C : Character) return Boolean is
     (C = ' ' or else C = Character'Val (9) or else C = Character'Val (10)
      or else C = Character'Val (13));

   procedure Find_Encoding
     (Input : String; Found : out Boolean; First : out Positive;
      Last : out Natural)
   is
      Length : constant Natural range 0 .. Natural'Last - 1 := Input'Last;
      P : Positive range 1 .. Length + 1;
      Name_First, Name_Last, Value_First : Positive;
      Quote : Character;
   begin
      Found := False;
      First := 1;
      Last := 0;
      --  "<?xml" and white space.
      if Length < 6 or else Input (1 .. 5) /= "<?xml"
        or else not Space (Input (6))
      then
         return;
      end if;
      P := 6;
      loop
         --  White space.
         while P <= Length and then Space (Input (P)) loop
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
         --  The end of the declaration, or something unexpected (the parser
         --  accepted the document, so this does not happen).
         exit when P > Length or else Input (P) = '?';
         Name_First := P;
         while P <= Length
           and then Input (P) /= '=' and then not Space (Input (P))
         loop
            pragma Loop_Invariant (P >= Name_First);
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
         exit when P = Name_First or else P > Length;
         Name_Last := P - 1;
         while P <= Length and then Space (Input (P)) loop
            pragma Loop_Invariant (P > Name_Last);
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
         exit when P > Length or else Input (P) /= '=';
         P := P + 1;
         while P <= Length and then Space (Input (P)) loop
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
         exit when P > Length
           or else (Input (P) /= ''' and then Input (P) /= '"');
         Quote := Input (P);
         exit when P = Length;
         P := P + 1;
         Value_First := P;
         while P <= Length and then Input (P) /= Quote loop
            pragma Loop_Invariant (P >= Value_First);
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
         exit when P > Length;
         if Name_Last - Name_First = 7
           and then Input (Name_First .. Name_Last) = "encoding"
         then
            if P > Value_First then
               Found := True;
               First := Value_First;
               Last := P - 1;
            end if;
            return;
         end if;
         P := P + 1;
      end loop;
   end Find_Encoding;

end XML3_Declarations;
