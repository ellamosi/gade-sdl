generic
   type Element_Type is private;
package Buffers.Circular is

   type Circular_Buffer (Size : Positive) is tagged private;

   procedure Push (Self : in out Circular_Buffer; E : Element_Type)
     with
       Pre  => Length (Self) <= Self.Size - 1 or else raise Constraint_Error,
       Post => Length (Self)'Old + 1 = Length (Self) and then Self.Size >= Length (Self);

   procedure Pop (Self : in out Circular_Buffer; E : out Element_Type)
     with
       Pre  => Length (Self) > 0 or else raise Constraint_Error,
       Post => Length (Self)'Old - 1 = Length (Self);

   function Peek (Self : Circular_Buffer) return Element_Type
     with Pre => Length (Self) > 0 or else raise Constraint_Error;

   function Length (Self : Circular_Buffer) return Natural;

   function Is_Empty (Self : Circular_Buffer) return Boolean;

   function Available (Self : Circular_Buffer) return Natural;

private

   type Data_Container is array (Positive range <>) of aliased Element_Type;

   type Data_Container_Access is access all Data_Container;

   type Circular_Buffer (Size : Positive) is tagged record
      Data : aliased Data_Container (1 .. Size);

      Read_Index  : Positive := 1;
      Write_Index : Positive := 1;
      Count       : Natural  := 0;
   end record;

end Buffers.Circular;
