with System;
with XML3_DOM;
with XML3_DOM_Store.Queries;
with XML3_Native_Memory;

package XML3_DOM_Store.Properties with SPARK_Mode is
   use XML3_DOM;
   use type System.Address;
   pragma Unevaluated_Use_Of_Old (Allow);

   procedure Add_Property
     (S : in out Store; Element, Attribute : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created
           then Result = Attribute and then Result /= System.Null_Address
           else Result = System.Null_Address);

   function Namespace_Attached
     (S : Store; Ns : System.Address) return Boolean
     with Ghost, Global => null, Pre => Ready (S),
       Annotate => (GNATprove, Inline_For_Proof);

   procedure Create_Property
     (S : in out Store; Element : System.Address;
      Name, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Result /= System.Null_Address else Result = System.Null_Address);

   procedure Create_Property
     (S : in out Store; Element, Name, Value : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Result /= System.Null_Address else Result = System.Null_Address);

   procedure Set_Property
     (S : in out Store; Element : System.Address;
      Name, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Result /= System.Null_Address else Result = System.Null_Address);

   procedure Create_Namespace_Property
     (S : in out Store; Element, Ns : System.Address;
      Name, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then Namespace_Attached (S, Ns) =
           Namespace_Attached (S, Ns)'Old
         and then (if Status = XML3_DOM_Constructors.Created
           then Result /= System.Null_Address
           else Result = System.Null_Address);

   procedure Set_Namespace_Property
     (S : in out Store; Element, Ns : System.Address;
      Name, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then Namespace_Attached (S, Ns) =
           Namespace_Attached (S, Ns)'Old
         and then (if Status = XML3_DOM_Constructors.Created
           then Result /= System.Null_Address
           else Result = System.Null_Address);

   procedure Unset_Namespace_Property
     (S : in out Store; Element, Ns : System.Address; Name : String;
      Removed : out Boolean; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory);

   procedure Set_Qualified_Property
     (S : in out Store; Element : System.Address;
      QName, Value : String; Has_Value : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created
           then Result /= System.Null_Address
           else Result = System.Null_Address);
   procedure Set_XML_Property
     (S : in out Store; Element : System.Address;
      Mode : XML3_DOM_Store.Queries.XML_Property_Kind;
      Value : System.Address; Space_Value : Integer;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S), Post => Ready (S);
private
   function Namespace_Attached
     (S : Store; Ns : System.Address) return Boolean is
     (S.Current /= null and then Ns /= System.Null_Address
      and then (for some I in Namespace_Ref range
        1 .. Namespace_Ref (Namespace_Count (S.Current.all)) =>
          Namespace (S.Current.all, I).State = Live
          and then Namespace (S.Current.all, I).Facade = Ns
          and then Namespace (S.Current.all, I).Attached
          and then Namespace (S.Current.all, I).Owner in
            1 .. Owner_Ref (Owner_Count (S.Current.all))
          and then Owner
            (S.Current.all, Namespace (S.Current.all, I).Owner).State = Live));
end XML3_DOM_Store.Properties;
