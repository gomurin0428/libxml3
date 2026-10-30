with XML3_Parser.Outcomes;

package body XML3_Parser.Attempts with SPARK_Mode is

   procedure Run
     (Attempt      : not null Attempt_Procedure;
      Input_Length : XML3_Text.Byte_Count;
      Result       : out System.Address;
      Status       : out XML3_DOM_Store.Documents.Read_Status;
      Diagnostic   : out Diagnostic_Info;
      Limit        : XML3_Native_Memory.Byte_Count :=
        XML3_Native_Memory.Byte_Count'Last)
   is
      Capacity : Workspaces.Capacity :=
        Workspaces.Initial_Capacity (Input_Length);
      Workspace : Workspaces.Buffers;
      Allocated : Workspaces.Allocation_Result;
   begin
      Result := System.Null_Address;
      Diagnostic :=
        (Domain => 1, Code => 0, Level => 0, Byte_Position => 1,
         Int1 => 0, Int2 => 0);
      loop
         pragma Loop_Invariant (Workspaces.Empty (Workspace));
         pragma Loop_Variant (Increases => Capacity);
         Workspaces.Allocate
           (Capacity, Input_Length, Workspace, Allocated, Limit);
         case Allocated is
            when Workspaces.No_Memory | Workspaces.Limit_Exceeded =>
               Status := XML3_DOM_Store.Documents.No_Memory;
               pragma Assert (Workspaces.Empty (Workspace));
               return;
            when Workspaces.Allocated =>
               null;
         end case;
         Attempt (Capacity, Workspace, Result, Status, Diagnostic);
         Workspaces.Release (Workspace);
         pragma Assert (Workspaces.Empty (Workspace));
         case Outcomes.After_Attempt (Status, Capacity) is
            when Outcomes.Finished =>
               exit;
            when Outcomes.Limit_Reached =>
               Status := XML3_DOM_Store.Documents.Limit_Exceeded;
               return;
            when Outcomes.Grow =>
               Capacity := Workspaces.Next_Capacity (Capacity);
         end case;
      end loop;
      pragma Assert (Workspaces.Empty (Workspace));
   end Run;

end XML3_Parser.Attempts;
