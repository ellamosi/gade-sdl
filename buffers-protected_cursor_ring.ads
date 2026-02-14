generic
   type Element_Type is private;
package Buffers.Protected_Cursor_Ring is

   type Protected_Circular_Buffer (Size : Positive) is tagged limited private;

   type Cursor is tagged limited private;

   function Has_Element (C : Cursor) return Boolean;

   type Read_Cursor is limited new Cursor with private;
   type Write_Cursor is limited new Cursor with private;

   procedure Begin_Write (Self : aliased in out Protected_Circular_Buffer;
                          C    : out Write_Cursor'Class);

   procedure Push
     (C : in out Write_Cursor;
      E : Element_Type);

   procedure Commit_Write (C : Write_Cursor);

   procedure Begin_Read (Self : aliased in out Protected_Circular_Buffer;
                         C    : out Read_Cursor'Class);

   procedure Pop
     (C : in out Read_Cursor;
      E : out Element_Type);

   procedure Commit_Read (C : Read_Cursor);

--     function Peek (Self : Protected_Circular_Buffer) return Element_Type
--       with Pre => Length (Self) > 0 or else raise Constraint_Error;
--
   function Length (Self : Protected_Circular_Buffer) return Natural;
--
--     function Is_Empty (Self : Protected_Circular_Buffer) return Boolean;
--
--     function Available (Self : Protected_Circular_Buffer) return Natural;

private

   type Data_Container is array (Positive range <>) of aliased Element_Type;

   --  type Data_Container_Access is access all Data_Container;

   type Protected_Circular_Buffer_Access is access all Protected_Circular_Buffer;

   type Cursor is tagged limited record
      Index     : Positive;
      Remaining : Natural;
      Total     : Natural;
      Buffer    : access Protected_Circular_Buffer;
   end record;

   procedure Next (C : in out Cursor);

   type Read_Cursor is limited new Cursor with null record;
   type Write_Cursor is limited new Cursor with null record;

   protected type Committed_Context (Size : Positive) is
      procedure Read (Buffer : Protected_Circular_Buffer_Access;
                      C      : out Read_Cursor'Class);
      procedure Commit (C : Read_Cursor);

      procedure Write (Buffer : Protected_Circular_Buffer_Access;
                       C      : out Write_Cursor'Class);
      procedure Commit (C : Write_Cursor);

      function Length return Natural;
   private
      Read_Index  : Positive := 1;
      Write_Index : Positive := 1;
      Count       : Natural  := 0;
   end Committed_Context;

   type Protected_Circular_Buffer (Size : Positive) is tagged limited record
      Data : aliased Data_Container (1 .. Size);

      Committed   : Committed_Context (Size);
      Read_Index  : Positive := 1;
      Write_Index : Positive := 1;
      Count       : Natural  := 0;
   end record;

end Buffers.Protected_Cursor_Ring;
