with XML3_Text.Buffers;

package body XML3_Error_Records with SPARK_Mode is
   use type XML3_Text.Buffers.Concatenate_Status;

   procedure Free_Pointer (Item : in out System.Address)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => Item = System.Null_Address
   is
   begin
      if Item /= System.Null_Address then
         XML3_Native_Memory.Free (Item);
         Item := System.Null_Address;
      end if;
   end Free_Pointer;

   procedure Release (Item : in out Error_Record) is
   begin
      Free_Pointer (Item.Message);
      Free_Pointer (Item.File);
      Free_Pointer (Item.Str1);
      Free_Pointer (Item.Str2);
      Free_Pointer (Item.Str3);
      Item := Empty_Record;
   end Release;

   procedure Copy_Field
     (Source : System.Address; Target : out System.Address; Success : out Boolean;
      Limit : XML3_Text.Byte_Count)
     with Global => (In_Out => XML3_Native_Memory.Foreign_Memory),
       Post => (if Success then
                  (Source = System.Null_Address) = (Target = System.Null_Address)
                else Target = System.Null_Address)
   is
      Status : XML3_Text.Buffers.Concatenate_Status;
   begin
      Target := System.Null_Address;
      Success := True;
      if Source /= System.Null_Address then
         XML3_Text.Buffers.Concatenate_Bytes
           (Source, System.Null_Address, 0, Target, Status, Limit);
         Success := Status = XML3_Text.Buffers.Copied;
      end if;
   end Copy_Field;

   procedure Clone
     (Source : Error_Record; Target : in out Error_Record; Success : out Boolean;
      Limit : XML3_Text.Byte_Count := XML3_Text.Max_Bytes)
   is
   begin
      Target :=
        (Domain => Source.Domain, Code => Source.Code, Level => Source.Level,
         Line => Source.Line, Int1 => Source.Int1, Int2 => Source.Int2,
         Ctxt => Source.Ctxt, Node => Source.Node, others => <>);
      Copy_Field (Source.Message, Target.Message, Success, Limit);
      if Success then
         Copy_Field (Source.File, Target.File, Success, Limit);
      end if;
      if Success then
         Copy_Field (Source.Str1, Target.Str1, Success, Limit);
      end if;
      if Success then
         Copy_Field (Source.Str2, Target.Str2, Success, Limit);
      end if;
      if Success then
         Copy_Field (Source.Str3, Target.Str3, Success, Limit);
      end if;
      if not Success then
         Release (Target);
      end if;
   end Clone;

   procedure Clear_Slot (Slot : in out Error_Slot) is
   begin
      if Slot.Emergency then
         Slot.Error := Empty_Record;
      else
         Release (Slot.Error);
      end if;
      Slot.Emergency := False;
   end Clear_Slot;

   procedure Install (Slot : in out Error_Slot; Replacement : in out Error_Record)
   is
   begin
      Clear_Slot (Slot);
      Slot.Error := Replacement;
      Replacement := Empty_Record;
   end Install;

   procedure Fill_Out_Of_Memory
     (Item : out Error_Record; Message : System.Address) is
   begin
      Item := Out_Of_Memory (Message);
   end Fill_Out_Of_Memory;

   procedure Install_Out_Of_Memory
     (Slot : in out Error_Slot; Message : System.Address) is
   begin
      Clear_Slot (Slot);
      Fill_Out_Of_Memory (Slot.Error, Message);
      Slot.Emergency := True;
   end Install_Out_Of_Memory;
end XML3_Error_Records;
