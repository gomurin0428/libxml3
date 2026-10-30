with System;
with XML3_Native_Memory;

package XML3_DOM_Store.Content with SPARK_Mode is
   use type XML3_DOM.Node_Kind;

   procedure New_Doc_Content
     (S : in out Store; Doc : System.Address; Kind : XML3_DOM.Node_Kind;
      Name, Content : String; Has_Content : Boolean; Result : out System.Address;
      Status : out Operation_Status; Ns : System.Address := System.Null_Address;
      Content_Source : System.Address := System.Null_Address;
      Source_Length : Natural := 0;
      Name_Source : System.Address := System.Null_Address;
      Source_Name_Length : Natural := 0)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S)
         and then (if Content_Source = System.Null_Address then Source_Length = 0
           else Has_Content and then Content'Length = 0)
         and then (if Name_Source = System.Null_Address then Source_Name_Length = 0
           else Name'Length = 0
             and then Kind in XML3_DOM.Element_Node | XML3_DOM.Attribute_Node |
               XML3_DOM.Processing_Instruction_Node),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);

   procedure New_Doc_Content_Bytes
     (S : in out Store; Doc : System.Address; Kind : XML3_DOM.Node_Kind;
      Name : String; Content : System.Address; Length : Integer;
      Terminated : Boolean; Result : out System.Address;
      Status : out Operation_Status;
      Name_Source : System.Address := System.Null_Address)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);

   procedure New_Doc_Node
     (S : in out Store; Doc, Ns, Name, Content : System.Address;
      Raw_Content : Boolean;
      Result : out System.Address; Status : out Operation_Status;
      Attribute_Mode : Boolean := False)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);

   procedure Parse_Content_List
     (S : in out Store; Doc : System.Address; Content : String;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S), Post => Ready (S)
         and then (if Status /= XML3_DOM_Constructors.Created then
           Result = System.Null_Address);

   procedure New_Child
     (S : in out Store; Parent, Ns, Name, Content : System.Address;
      Raw_Content : Boolean;
      Result : out System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);

   procedure Append
     (S : in out Store; Facade : System.Address; Suffix : String;
      Status : out Operation_Status; Has_Input : Boolean := False;
      Text_Only : Boolean := False)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S);

   procedure Set_Name
     (S : in out Store; Facade, Name : System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S), Post => Ready (S);

   procedure Set
     (S : in out Store; Facade : System.Address; Content : String;
      Has_Content : Boolean; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S);

private
   procedure Construct_Container
     (S : in out Store; Doc, Ns, Name : System.Address; Name_Length : Natural;
      Content : String; Content_Source : System.Address; Source_Length : Natural;
      Has_Text, Attribute_Mode : Boolean;
      Result : out System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => (S.Current = null
         or else
           (XML3_DOM.Valid (S.Current.all)
            and then XML3_DOM.Can_Edit (S.Current.all)
            and then not XML3_DOM.Projection_Required (S.Current.all)
            and then XML3_DOM.Facades_Present (S.Current.all)))
         and then Name /= System.Null_Address
         and then (if Content_Source = System.Null_Address then Source_Length = 0
           else Content'Length = 0),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);
end XML3_DOM_Store.Content;
