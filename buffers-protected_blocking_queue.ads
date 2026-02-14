private with Buffers.Circular;

generic
   type Element_Type is private;
package Buffers.Protected_Blocking_Queue is

   type Protected_Circular_Buffer (Size : Positive) is tagged limited private;

   procedure Push_Blocking
     (Self : in out Protected_Circular_Buffer;
      E    : Element_Type);

   procedure Push_Non_Blocking
     (Self : in out Protected_Circular_Buffer;
      E    : Element_Type);

   procedure Pop_Blocking
     (Self : in out Protected_Circular_Buffer;
      E    : out Element_Type);

   procedure Pop_Non_Blocking
     (Self : in out Protected_Circular_Buffer;
      E    : out Element_Type);

   function Peek (Self : Protected_Circular_Buffer)
                  return Element_Type;

   function Length (Self : Protected_Circular_Buffer) return Natural;

   function Is_Empty (Self : Protected_Circular_Buffer)
                      return Boolean;

   function Available (Self : Protected_Circular_Buffer) return Natural;

private

   package Circular_Buffers is new Buffers.Circular (Element_Type);

   protected type Protected_Circular_Buffer_Impl (Size : Positive) is

      entry Push_Blocking (E : Element_Type);

      procedure Push_Non_Blocking (E : Element_Type);

      entry Pop_Blocking (E : out Element_Type);

      procedure Pop_Non_Blocking (E : out Element_Type);

      function Peek return Element_Type;

      function Length return Natural;

      function Is_Empty return Boolean;

      function Available return Natural;

   private
      Buffer : Circular_Buffers.Circular_Buffer (Size);
   end Protected_Circular_Buffer_Impl;

   type Protected_Circular_Buffer (Size : Positive) is tagged limited record
      Protected_Buffer : Protected_Circular_Buffer_Impl (Size);
   end record;

end Buffers.Protected_Blocking_Queue;
