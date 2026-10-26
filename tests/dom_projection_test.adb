with Interfaces.C;
with System;
with XML3_Native_Memory;

procedure DOM_Projection_Test is
   use type Interfaces.C.int;
   use type System.Address;

   function Page_Allocate return System.Address
     with Import, Convention => C,
       External_Name => "projection_page_allocate";
   procedure Page_Readonly (Facade : System.Address)
     with Import, Convention => C,
       External_Name => "projection_page_readonly";
   procedure Page_Writable (Facade : System.Address)
     with Import, Convention => C,
       External_Name => "projection_page_writable";
   procedure Page_Free (Facade : System.Address)
     with Import, Convention => C,
       External_Name => "projection_page_free";
   function Marker return System.Address
     with Import, Convention => C, External_Name => "projection_marker";
   function Check_Node
     (Facade, Parent : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "projection_check_node";
   function Check_Document
     (Facade, Version : System.Address) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "projection_check_document";
   function Check_Namespace
     (Facade, Next : System.Address) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "projection_check_namespace";

   Facade : System.Address;
   Value : XML3_Native_Memory.Node_Projection;
   Ns_Value : XML3_Native_Memory.Namespace_Projection;
   Other : constant System.Address := Marker;
begin
   Facade := Page_Allocate;
   pragma Assert (Facade /= System.Null_Address);
   XML3_Native_Memory.Initialize_Node (Facade);
   Value :=
     (Id => 1, Is_Document => False, Node_Type => 1,
      Name => Marker, Parent => System.Null_Address, others => <>);
   XML3_Native_Memory.Write_Node (Facade, Value);
   Page_Readonly (Facade);
   XML3_Native_Memory.Write_Node (Facade, Value);
   Page_Writable (Facade);
   Value.Parent := Other;
   XML3_Native_Memory.Write_Node (Facade, Value);
   pragma Assert (Check_Node (Facade, Other) = 1);
   Page_Free (Facade);

   Facade := Page_Allocate;
   pragma Assert (Facade /= System.Null_Address);
   XML3_Native_Memory.Initialize_Node (Facade);
   Value :=
     (Id => 2, Is_Document => True, Node_Type => 9,
      Name => Marker, Content => Marker, others => <>);
   XML3_Native_Memory.Write_Node (Facade, Value);
   Page_Readonly (Facade);
   XML3_Native_Memory.Write_Node (Facade, Value);
   Page_Writable (Facade);
   Value.Content := System.Null_Address;
   XML3_Native_Memory.Write_Node (Facade, Value);
   pragma Assert (Check_Document (Facade, System.Null_Address) = 1);
   Page_Free (Facade);

   Facade := Page_Allocate;
   pragma Assert (Facade /= System.Null_Address);
   XML3_Native_Memory.Initialize_Namespace (Facade);
   Ns_Value := (Id => 3, Href => Marker, Prefix => Marker, others => <>);
   XML3_Native_Memory.Write_Namespace (Facade, Ns_Value);
   Page_Readonly (Facade);
   XML3_Native_Memory.Write_Namespace (Facade, Ns_Value);
   Page_Writable (Facade);
   Ns_Value.Next := Other;
   XML3_Native_Memory.Write_Namespace (Facade, Ns_Value);
   pragma Assert (Check_Namespace (Facade, Other) = 1);
   Page_Free (Facade);
end DOM_Projection_Test;
