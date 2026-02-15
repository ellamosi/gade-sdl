package body Buffers.Transactional_Ring is

   function Has_Element (C : Cursor) return Boolean is
   begin
      return C.Remaining > 0;
   end Has_Element;

   procedure Begin_Write
     (Self : aliased in out Transactional_Ring_Buffer;
      C    : out Write_Cursor'Class)
   is
   begin
      Self.Committed.Write (Self'Unchecked_Access, C);
   end Begin_Write;

   procedure Push (C : in out Write_Cursor; E : Element_Type) is
   begin
      C.Buffer.Data (C.Index) := E;
      Next (C);
   end Push;

   procedure Commit_Write (C : Write_Cursor) is
   begin
      C.Buffer.Committed.Commit (C);
   end Commit_Write;

   procedure Begin_Read
     (Self : aliased in out Transactional_Ring_Buffer;
      C    : out Read_Cursor'Class)
   is
   begin
      Self.Committed.Read (Self'Unchecked_Access, C);
   end Begin_Read;

   procedure Pop (C : in out Read_Cursor; E : out Element_Type) is
   begin
      E := C.Buffer.Data (C.Index);
      Next (C);
   end Pop;

   procedure Commit_Read (C : Read_Cursor) is
   begin
      C.Buffer.Committed.Commit (C);
   end Commit_Read;

   function Length (Self : Transactional_Ring_Buffer) return Natural is
   begin
      return Self.Committed.Length;
   end Length;

   procedure Next (C : in out Cursor) is
   begin
      C.Index := C.Index + 1;
      if C.Index > C.Buffer.all.Size then C.Index := 1; end if;
      C.Remaining := C.Remaining - 1;
   end Next;

   protected body Committed_Context is
      procedure Read (Buffer : Transactional_Ring_Buffer_Access;
                      C      : out Read_Cursor'Class)
      is
      begin
         C.Index     := Read_Index;
         C.Remaining := Count;
         C.Total     := Count;
         C.Buffer    := Buffer;
      end Read;

      procedure Commit (C : Read_Cursor) is
      begin
         Read_Index := C.Index;
         Count := Count - (C.Total - C.Remaining);
      end Commit;

      procedure Write (Buffer : Transactional_Ring_Buffer_Access;
                       C      : out Write_Cursor'Class)
      is
         Total : constant Natural := Size - Count;
      begin
         C.Index     := Write_Index;
         C.Remaining := Total;
         C.Total     := Total;
         C.Buffer    := Buffer;
      end Write;

      procedure Commit (C : Write_Cursor) is
      begin
         Write_Index := C.Index;
         Count := Count + (C.Total - C.Remaining);
      end Commit;

      function Length return Natural is
      begin
         return Count;
      end Length;
   end Committed_Context;

end Buffers.Transactional_Ring;
