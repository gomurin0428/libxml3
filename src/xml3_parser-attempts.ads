with System;
with XML3_DOM_Store.Documents;
with XML3_Native_Memory;
with XML3_Parser.Workspaces;

package XML3_Parser.Attempts with SPARK_Mode is
   use type XML3_DOM_Store.Documents.Read_Status;

   --  One parse attempt over an allocated workspace.  The attempt never
   --  allocates or releases the workspace itself and never propagates an
   --  exception; the adapter implementation catches all of them and maps
   --  them onto a read status.  GNAT rejects Always_Terminates on an
   --  access-to-subprogram type, so the termination of a single attempt
   --  stays a trusted property of the supplied procedure; what Run adds is
   --  the proof that the retry loop itself makes progress and stops.
   type Attempt_Procedure is access procedure
     (Capacity   : Workspaces.Capacity;
      Workspace  : Workspaces.Buffers;
      Result     : out System.Address;
      Status     : out XML3_DOM_Store.Documents.Read_Status;
      Diagnostic : out Diagnostic_Info)
   with Pre => Workspaces.Ready (Workspace);

   --  Drives the growing retry loop: allocate a workspace, run one attempt,
   --  release the workspace, then either finish, grow the node arena, or
   --  report the node limit.  Every exit releases the workspace it holds.
   procedure Run
     (Attempt      : not null Attempt_Procedure;
      Input_Length : XML3_Text.Byte_Count;
      Result       : out System.Address;
      Status       : out XML3_DOM_Store.Documents.Read_Status;
      Diagnostic   : out Diagnostic_Info;
      Limit        : XML3_Native_Memory.Byte_Count :=
        XML3_Native_Memory.Byte_Count'Last)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Status /= XML3_DOM_Store.Documents.Arena_Exhausted;

end XML3_Parser.Attempts;
