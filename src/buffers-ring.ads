generic
   type Element_Type is private;
package Buffers.Ring is

   --  Fixed-capacity FIFO ring buffer with immediate push/pop operations.
   type Ring_Buffer (Size : Positive) is tagged private;

   procedure Push (Self : in out Ring_Buffer; E : Element_Type)
     with
       Pre  => Length (Self) <= Self.Size - 1,
       Post => Length (Self)'Old + 1 = Length (Self) and then Self.Size >= Length (Self);

   procedure Pop (Self : in out Ring_Buffer; E : out Element_Type)
     with
       Pre  => Length (Self) > 0,
       Post => Length (Self)'Old - 1 = Length (Self);

   function Peek (Self : Ring_Buffer) return Element_Type
     with Pre => Length (Self) > 0;

   function Length (Self : Ring_Buffer) return Natural;

   function Is_Empty (Self : Ring_Buffer) return Boolean;

   function Available (Self : Ring_Buffer) return Natural;

private

   type Data_Container is array (Positive range <>) of aliased Element_Type;

   type Ring_Buffer (Size : Positive) is tagged record
      Data : aliased Data_Container (1 .. Size);

      Read_Index  : Positive := 1;
      Write_Index : Positive := 1;
      Count       : Natural  := 0;
   end record;

end Buffers.Ring;
