with XML3_DOM_Constructors;

package body XML3_DOM_Store.Serialization with SPARK_Mode is
   use type System.Address;
   use type XML3_DOM.Node_Ref;
   use type XML3_DOM.Node_Kind;

   procedure Dump
     (S : Store; Document, Encoding : System.Address;
      Result : out System.Address; Length : out Natural;
      Status : out Operation_Status;
      Formatted : Boolean := False)
   is
      N : XML3_DOM.Node_Ref;
      Name : XML3_Serialization.UTF8_Name := "UTF-8";
      Valid : Boolean;
      Default_Encoding : constant Boolean := Encoding = System.Null_Address;
   begin
      Result := System.Null_Address;
      Length := 0;
      Status := XML3_DOM_Constructors.Invalid_Argument;
      if S.Current = null or else Document = System.Null_Address then
         return;
      end if;
      N := Find_Registered_Node (S, Document);
      if N = XML3_DOM.Null_Node
        or else XML3_DOM.Node (S.Current.all, N).Kind /=
          XML3_DOM.Document_Node
      then
         return;
      end if;
      if not Default_Encoding then
         XML3_Serialization.Read_UTF8_Name (Encoding, Name, Valid);
         if not Valid then
            return;
         end if;
      end if;
      XML3_Serialization.Render
        (S.Current.all, N, Name, Result, Length, Status,
         Default_Encoding, Formatted);
   end Dump;

   procedure Dump_Node
     (S : Store; Node_Facade : System.Address; Level : Integer;
      Formatted : Boolean;
      Result : out System.Address; Length : out Natural;
      Status : out Operation_Status)
   is
      N : XML3_DOM.Node_Ref;
   begin
      Result := System.Null_Address;
      Length := 0;
      Status := XML3_DOM_Constructors.Invalid_Argument;
      if S.Current = null or else Node_Facade = System.Null_Address then
         return;
      end if;
      N := Find_Registered_Node (S, Node_Facade);
      if N = XML3_DOM.Null_Node then
         return;
      end if;
      XML3_Serialization.Render
        (S.Current.all, N, "UTF-8", Result, Length, Status,
         Default_Encoding => False, Formatted => Formatted,
         Level => Clamped_Level (Level));
   end Dump_Node;

   procedure Save
     (S : Store; Node_Facade, Encoding : System.Address;
      Document_Only, Formatted : Boolean;
      Style : XML3_Serialization.Output_Style;
      Result : out System.Address; Length : out Natural;
      Status : out Operation_Status)
   is
      N : XML3_DOM.Node_Ref;
      Name : XML3_Serialization.UTF8_Name := "UTF-8";
      Valid : Boolean;
      Default_Encoding : constant Boolean := Encoding = System.Null_Address;
   begin
      Result := System.Null_Address;
      Length := 0;
      Status := XML3_DOM_Constructors.Invalid_Argument;
      if S.Current = null or else Node_Facade = System.Null_Address then
         return;
      end if;
      N := Find_Registered_Node (S, Node_Facade);
      if N = XML3_DOM.Null_Node
        or else (Document_Only
                 and then XML3_DOM.Node (S.Current.all, N).Kind /=
                   XML3_DOM.Document_Node)
      then
         return;
      end if;
      if not Default_Encoding then
         XML3_Serialization.Read_UTF8_Name (Encoding, Name, Valid);
         if not Valid then
            return;
         end if;
      end if;
      XML3_Serialization.Render
        (S.Current.all, N, Name, Result, Length, Status,
         Default_Encoding => Default_Encoding, Formatted => Formatted,
         Level => 0, Style => Style);
   end Save;
end XML3_DOM_Store.Serialization;
