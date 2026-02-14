package body Buffers.Circular is

   procedure Push (Self : in out Circular_Buffer; E : Element_Type) is
   begin
      Self.Data (Self.Write_Index) := E;
      Self.Write_Index := Self.Write_Index + 1;
      Self.Count := Self.Count + 1;
      if Self.Write_Index > Self.Size then Self.Write_Index := 1; end if;
   end Push;

   procedure Pop (Self : in out Circular_Buffer; E : out Element_Type) is
   begin
      E := Self.Data (Self.Read_Index);
      Self.Read_Index := Self.Read_Index + 1;
      Self.Count := Self.Count - 1;
      if Self.Read_Index > Self.Size then Self.Read_Index := 1; end if;
   end Pop;

   function Peek (Self : Circular_Buffer) return Element_Type is
   begin
      return Self.Data (Self.Read_Index);
   end Peek;

   function Length (Self : Circular_Buffer) return Natural is
   begin
      return Self.Count;
   end Length;

   function Is_Empty (Self : Circular_Buffer) return Boolean is
   begin
      return Self.Length = 0;
   end Is_Empty;

   function Available (Self : Circular_Buffer) return Natural is
   begin
      return Self.Size - Self.Length;
   end Available;

end Buffers.Circular;
