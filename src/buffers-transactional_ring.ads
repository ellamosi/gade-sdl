generic
   type Element_Type is private;
package Buffers.Transactional_Ring is

   --  Fixed-capacity FIFO ring with cursor-based begin/commit transactions
   --  for batched producer/consumer access.
   --
   --  Concurrency contract:
   --  - Intended for single-producer/single-consumer use.
   --  - At most one active Write_Cursor at a time.
   --  - At most one active Read_Cursor at a time.
   --  - A read cursor and a write cursor may be active concurrently.
   --
   --  Violating this (e.g. overlapping Begin_Write/Begin_Read from multiple
   --  producers/consumers) can produce overlapping cursors and incorrect
   --  committed Count/index state.
   type Transactional_Ring_Buffer (Size : Positive) is tagged limited private;

   type Cursor is tagged limited private;

   function Has_Element (C : Cursor) return Boolean;

   type Read_Cursor is limited new Cursor with private;
   type Write_Cursor is limited new Cursor with private;

   procedure Begin_Write (Self : aliased in out Transactional_Ring_Buffer;
                          C    : out Write_Cursor'Class);
   --  Precondition-by-contract: no other uncommitted Write_Cursor exists.

   procedure Push
     (C : in out Write_Cursor;
      E : Element_Type);

   procedure Commit_Write (C : Write_Cursor);
   --  Must commit the same cursor returned by Begin_Write before issuing
   --  another Begin_Write.

   procedure Begin_Read (Self : aliased in out Transactional_Ring_Buffer;
                         C    : out Read_Cursor'Class);
   --  Precondition-by-contract: no other uncommitted Read_Cursor exists.

   procedure Pop
     (C : in out Read_Cursor;
      E : out Element_Type);

   procedure Commit_Read (C : Read_Cursor);
   --  Must commit the same cursor returned by Begin_Read before issuing
   --  another Begin_Read.

   function Length (Self : Transactional_Ring_Buffer) return Natural;

private

   type Data_Container is array (Positive range <>) of aliased Element_Type;

   type Transactional_Ring_Buffer_Access is access all Transactional_Ring_Buffer;

   type Cursor is tagged limited record
      Index     : Positive;
      Remaining : Natural;
      Total     : Natural;
      Buffer    : access Transactional_Ring_Buffer;
   end record;

   procedure Next (C : in out Cursor);

   type Read_Cursor is limited new Cursor with null record;
   type Write_Cursor is limited new Cursor with null record;

   protected type Committed_Context (Size : Positive) is
      procedure Read (Buffer : Transactional_Ring_Buffer_Access;
                      C      : out Read_Cursor'Class);
      procedure Commit (C : Read_Cursor);

      procedure Write (Buffer : Transactional_Ring_Buffer_Access;
                       C      : out Write_Cursor'Class);
      procedure Commit (C : Write_Cursor);

      function Length return Natural;
   private
      Read_Index  : Positive := 1;
      Write_Index : Positive := 1;
      Count       : Natural  := 0;
   end Committed_Context;

   type Transactional_Ring_Buffer (Size : Positive) is tagged limited record
      Data      : aliased Data_Container (1 .. Size);
      Committed : Committed_Context (Size);
   end record;

end Buffers.Transactional_Ring;
