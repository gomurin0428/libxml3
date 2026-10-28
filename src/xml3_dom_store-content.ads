with System;
with XML3_Native_Memory;

package XML3_DOM_Store.Content with SPARK_Mode is
   procedure Append
     (S : in out Store; Facade : System.Address; Suffix : String;
      Status : out Operation_Status)
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
