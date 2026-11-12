with System;
with XML3_DOM_Constructors;
with XML3_Native_Memory;
with XML3_Serialization;

package XML3_DOM_Store.Serialization with SPARK_Mode is
   procedure Dump
     (S : Store; Document, Encoding : System.Address;
      Result : out System.Address; Length : out Natural;
      Status : out Operation_Status;
      Formatted : Boolean := False)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Length <= Integer'Last - 1
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address
         else Result = System.Null_Address and then Length = 0);

   --  xmlNodeDump: the subtree of a registered node, indented from Level
   --  (clamped to 0 .. 100 as libxml2 does) when Formatted.  A document
   --  node is dumped whole, with an UTF-8 encoding declaration.
   procedure Dump_Node
     (S : Store; Node_Facade : System.Address; Level : Integer;
      Formatted : Boolean;
      Result : out System.Address; Length : out Natural;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Length <= Integer'Last - 1
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address
         else Result = System.Null_Address and then Length = 0);

   --  xmlSaveDoc (Document_Only) and xmlSaveTree: the registered document,
   --  or any registered node's subtree, with the xmlsave.h Style, formatted
   --  from level 0.  A null Encoding is the save context without an
   --  encoding: no encoding declaration, non-ASCII characters as character
   --  references.
   procedure Save
     (S : Store; Node_Facade, Encoding : System.Address;
      Document_Only, Formatted : Boolean;
      Style : XML3_Serialization.Output_Style;
      Result : out System.Address; Length : out Natural;
      Status : out Operation_Status)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Ready (S),
       Post => Length <= Integer'Last - 1
         and then (if Status = XML3_DOM_Constructors.Created then
           Result /= System.Null_Address
         else Result = System.Null_Address and then Length = 0);

   function Clamped_Level (Level : Integer) return Natural is
     (if Level < 0 then 0 elsif Level > 100 then 100 else Level)
     with Global => null;
end XML3_DOM_Store.Serialization;
