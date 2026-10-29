with System;
with XML3_Native_Memory;

package XML3_DOM_Store.Content with SPARK_Mode is
   procedure New_Doc_Content
     (S : in out Store; Doc : System.Address; Kind : XML3_DOM.Node_Kind;
      Name, Content : String; Has_Content : Boolean; Result : out System.Address;
      Status : out Operation_Status; Ns : System.Address := System.Null_Address;
      Content_Source : System.Address := System.Null_Address;
      Source_Length : Natural := 0)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S)
         and then (if Content_Source = System.Null_Address then Source_Length = 0
           else Has_Content and then Content'Length = 0),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);

   procedure New_Doc_Content_Bytes
     (S : in out Store; Doc : System.Address; Kind : XML3_DOM.Node_Kind;
      Name : String; Content : System.Address; Length : Integer;
      Terminated : Boolean; Result : out System.Address;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);

   procedure New_Doc_Node
     (S : in out Store; Doc, Ns : System.Address;
      Name, Content : String; Raw_Content, Has_Content : Boolean;
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
     (S : in out Store; Parent, Ns : System.Address;
      Name, Content : String; Raw_Content, Has_Content : Boolean;
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
end XML3_DOM_Store.Content;
