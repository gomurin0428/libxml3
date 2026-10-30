with XML3_Native_Memory;
with XML3_Text;

package XML3_DOM_Store.Queries with SPARK_Mode is
   type Element_Query_Kind is
     (Document_Root, First_Element, Last_Element,
      Next_Element, Previous_Element, Element_Count, Last_Child_Node);
   type Property_Filter is (Any_Namespace, No_Namespace, Exact_Namespace);
   type Namespace_Query_Kind is (Prefix_Search, Href_Search);
   type Node_Test_Kind is (Text_Test, Blank_Test);
   type XML_Property_Kind is (Language_Property, Space_Property);
   type Space_Policy is (Unspecified, Default_Space, Preserve_Space);

   procedure Find_Matching_Property
     (S : Store; Element, Attribute : System.Address;
      Result : out System.Address; Status : out Operation_Status;
      Name : System.Address := System.Null_Address; Name_Length : Natural := 0;
      Exclude_Source : Boolean := False)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   procedure Get_Inherited_XML_Property
     (S : Store; Facade : System.Address; Mode : XML_Property_Kind;
      Result : out System.Address; Space : out Space_Policy;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Mode = Space_Property then Result = System.Null_Address)
         and then (if Mode = Language_Property then Space = Unspecified)
         and then (if Status /= XML3_DOM_Constructors.Created then
           Result = System.Null_Address and then Space = Unspecified);

   procedure Test_Node
     (S : Store; Facade : System.Address; Mode : Node_Test_Kind;
      Result : out Boolean; Status : out Operation_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then not Result);

   procedure Select_Element
     (S : Store; Facade : System.Address; Mode : Element_Query_Kind;
      Result : out System.Address; Count : out Natural;
      Status : out Operation_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address and then Count = 0);

   procedure Find_Property
     (S : Store; Element : System.Address; Name : String;
      Filter : Property_Filter; Href : String;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   procedure Find_Property
     (S : Store; Element, Name : System.Address;
      Filter : Property_Filter; Href : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   procedure Get_Namespace_List
     (S : Store; Facade : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   procedure Lookup_Namespace
     (S : in out Store; Facade : System.Address; Mode : Namespace_Query_Kind;
      Has_Value : Boolean; Value : String;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   procedure Lookup_Namespace
     (S : in out Store; Facade : System.Address; Mode : Namespace_Query_Kind;
      Value : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   procedure Search_Namespace
     (S : Store; Facade : System.Address; Mode : Namespace_Query_Kind;
      Has_Value : Boolean; Value : String;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
         Result = System.Null_Address);

   --  The returned string is caller-owned, not a registered DOM allocation.
   procedure Get_Content
     (S : Store; Facade : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Result /= System.Null_Address else Result = System.Null_Address);

   procedure Get_Path
     (S : Store; Facade : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Result /= System.Null_Address else Result = System.Null_Address);

   procedure Get_Line_Number
     (S : Store; Facade : System.Address; Result : out Integer)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Result in -1 .. 65_535;

   procedure Get_List_Content
     (S : Store; Facade : System.Address; Escape : Boolean;
      Result : out System.Address; Status : out Operation_Status;
      Doc : System.Address := System.Null_Address;
      Default_Entities : Boolean := False)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Result /= System.Null_Address else Result = System.Null_Address);

   procedure Get_Document_Entity
     (S : Store; Document, Name : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (Input => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status /= XML3_DOM_Constructors.Created then
                  Result = System.Null_Address)
         and then (if Name = System.Null_Address then
                     Status = XML3_DOM_Constructors.Created
                     and Result = System.Null_Address);

   procedure Encode_Entities
     (S : Store; Document, Input : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => (if Status = XML3_DOM_Constructors.Created then
         Result /= System.Null_Address else Result = System.Null_Address);
end XML3_DOM_Store.Queries;
