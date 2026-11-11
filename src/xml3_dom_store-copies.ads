with System;
with XML3_Native_Memory;

--  Node, property and document copies (xmlCopyNode, xmlDocCopyNode,
--  xmlCopyProp, xmlCopyDoc), composed from the Store's construction,
--  attachment, namespace and release operations.  A failed copy releases
--  everything it created, except namespace declarations that libxml2 also
--  leaves in place on an existing tree (see Copy_Property).
package XML3_DOM_Store.Copies with SPARK_Mode is

   --  The `extended` argument of xmlCopyNode and xmlDocCopyNode: 0 copies
   --  the node alone, 2 also copies the properties and namespaces of an
   --  element, and any other value copies the whole subtree.
   type Copy_Mode is (Shallow, With_Properties, Deep);

   function Mode_For (Extended : Integer) return Copy_Mode is
     (if Extended = 0 then Shallow
      elsif Extended = 2 then With_Properties
      else Deep)
   with Global => null;

   --  xmlCopyNode (Doc = Null_Address) and xmlDocCopyNode.  A document is
   --  copied as by Copy_Document, recursively unless Mode is Shallow; an
   --  attribute as by Copy_Property without a target.
   procedure Copy_Node
     (S : in out Store; Source, Doc : System.Address; Mode : Copy_Mode;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created
                   then Result /= System.Null_Address
                   else Result = System.Null_Address);

   --  xmlCopyProp.  The copy is returned unattached; libxml2 additionally
   --  points its parent at Target without linking it.
   procedure Copy_Property
     (S : in out Store; Target, Source : System.Address;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created
                   then Result /= System.Null_Address
                   else Result = System.Null_Address);

   --  xmlCopyDoc.
   procedure Copy_Document
     (S : in out Store; Source : System.Address; Recursive : Boolean;
      Result : out System.Address; Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Ready (S)
         and then (if Status = XML3_DOM_Constructors.Created
                   then Result /= System.Null_Address
                   else Result = System.Null_Address);

end XML3_DOM_Store.Copies;
