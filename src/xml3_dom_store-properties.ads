with XML3_Native_Memory;

package XML3_DOM_Store.Properties with SPARK_Mode is
   procedure Create_Property
     (S : in out Store; Element : System.Address;
      Name, Value : String; Has_Value : Boolean;
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
end XML3_DOM_Store.Properties;
