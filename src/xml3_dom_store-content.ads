with System;
with XML3_Native_Memory;

package XML3_DOM_Store.Content with SPARK_Mode is
   procedure New_Doc_Content
     (S : in out Store; Doc : System.Address; Kind : XML3_DOM.Node_Kind;
      Name, Content : String; Has_Content : Boolean; Result : out System.Address;
      Status : out Operation_Status; Ns : System.Address := System.Null_Address)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);

   procedure New_Doc_Node
     (S : in out Store; Doc, Ns : System.Address;
      Name, Content : String; Raw_Content, Has_Content : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address else Result = System.Null_Address);

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
      Status : out Operation_Status; Has_Input : Boolean := False)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S);

   procedure Set
     (S : in out Store; Facade : System.Address; Content : String;
      Has_Content : Boolean; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S);
end XML3_DOM_Store.Content;
