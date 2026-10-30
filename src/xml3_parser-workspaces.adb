with XML3_Parser.Native_Sizes;

package body XML3_Parser.Workspaces with SPARK_Mode is
   package Native renames XML3_Native_Memory;
   package Sizes renames XML3_Parser.Native_Sizes;
   use type Native.Byte_Count;

   function Initial_Capacity (Input_Length : XML3_Text.Byte_Count) return Capacity is
     (Natural'Max (1, Natural'Min (2_048, Input_Length)));

   function Next_Capacity (Current : Capacity) return Capacity is
     (if Current > Capacity'Last / 2 then Capacity'Last else Current * 2);

   procedure Release (Item : in out Buffers) is
   begin
      if Item.Nodes /= System.Null_Address then
         Native.Free (Item.Nodes);
      end if;
      if Item.Names /= System.Null_Address then
         Native.Free (Item.Names);
      end if;
      if Item.Scratch_A /= System.Null_Address then
         Native.Free (Item.Scratch_A);
      end if;
      if Item.Scratch_B /= System.Null_Address then
         Native.Free (Item.Scratch_B);
      end if;
      Item := (others => <>);
   end Release;

   procedure Allocate
     (Count : Capacity; Input_Length : XML3_Text.Byte_Count;
      Result : in out Buffers; Status : out Allocation_Result;
      Limit : Native.Byte_Count := Native.Byte_Count'Last)
   is
      Entries : constant Native.Byte_Count := Native.Byte_Count (Count);
      Scratch_Bytes : constant Native.Positive_Byte_Count :=
        Native.Byte_Count (Natural'Max (1, Input_Length));
   begin
      Result := (others => <>);
      Status := Limit_Exceeded;
      if Entries > Limit / Sizes.Node_Bytes
        or else Entries > Limit / Sizes.Name_Bytes
        or else Scratch_Bytes > Limit
      then
         return;
      end if;
      Native.Allocate (Entries * Sizes.Node_Bytes, Result.Nodes);
      Native.Allocate (Entries * Sizes.Name_Bytes, Result.Names);
      Native.Allocate (Scratch_Bytes, Result.Scratch_A);
      Native.Allocate (Scratch_Bytes, Result.Scratch_B);
      if Ready (Result) then
         Status := Allocated;
      else
         Release (Result);
         Status := No_Memory;
      end if;
   end Allocate;
end XML3_Parser.Workspaces;
