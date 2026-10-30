with XML3_Namespaces;
with XML3_Native_Memory;

package XML3_Parser.Native_Sizes with SPARK_Mode is
   Node_Bytes : constant XML3_Native_Memory.Positive_Byte_Count;
   Name_Bytes : constant XML3_Native_Memory.Positive_Byte_Count;

private
   pragma SPARK_Mode (Off);

   Node_Bytes : constant XML3_Native_Memory.Positive_Byte_Count :=
     XML3_Parser.Node'Max_Size_In_Storage_Elements;
   Name_Bytes : constant XML3_Native_Memory.Positive_Byte_Count :=
     XML3_Namespaces.Name_Info'Max_Size_In_Storage_Elements;
end XML3_Parser.Native_Sizes;
