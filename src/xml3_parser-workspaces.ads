with System;
with XML3_Native_Memory;

package XML3_Parser.Workspaces with SPARK_Mode is
   use type System.Address;
   subtype Capacity is Positive range 1 .. Max_Nodes;

   type Buffers is record
      Nodes, Names, Scratch_A, Scratch_B : System.Address := System.Null_Address;
   end record;

   function Empty (Item : Buffers) return Boolean is
     (Item.Nodes = System.Null_Address and then Item.Names = System.Null_Address
      and then Item.Scratch_A = System.Null_Address
      and then Item.Scratch_B = System.Null_Address);

   function Ready (Item : Buffers) return Boolean is
     (Item.Nodes /= System.Null_Address and then Item.Names /= System.Null_Address
      and then Item.Scratch_A /= System.Null_Address
      and then Item.Scratch_B /= System.Null_Address);

   function Initial_Capacity (Input_Length : XML3_Text.Byte_Count) return Capacity
     with Global => null;

   function Next_Capacity (Current : Capacity) return Capacity
     with Global => null,
       Post => Next_Capacity'Result >= Current
         and then (if Current < Capacity'Last then Next_Capacity'Result > Current);

   type Allocation_Result is (Allocated, No_Memory, Limit_Exceeded);

   procedure Allocate
     (Count : Capacity; Input_Length : XML3_Text.Byte_Count;
      Result : in out Buffers; Status : out Allocation_Result;
      Limit : XML3_Native_Memory.Byte_Count := XML3_Native_Memory.Byte_Count'Last)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Pre => Empty (Result),
       Post => (if Status = Allocated then Ready (Result) else Empty (Result));

   procedure Release (Item : in out Buffers)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Empty (Item);

end XML3_Parser.Workspaces;
