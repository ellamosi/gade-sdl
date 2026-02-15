private with Buffers.Ring;

generic
   type Element_Type is private;
package Buffers.Protected_Blocking_Queue is

   type Protected_Blocking_Queue (Size : Positive) is tagged limited private;

   procedure Push_Blocking
     (Self : in out Protected_Blocking_Queue;
      E    : Element_Type);

   procedure Push_Non_Blocking
     (Self : in out Protected_Blocking_Queue;
      E    : Element_Type);

   procedure Pop_Blocking
     (Self : in out Protected_Blocking_Queue;
      E    : out Element_Type);

   procedure Pop_Non_Blocking
     (Self : in out Protected_Blocking_Queue;
      E    : out Element_Type);

   function Peek (Self : Protected_Blocking_Queue)
                  return Element_Type;

   function Length (Self : Protected_Blocking_Queue) return Natural;

   function Is_Empty (Self : Protected_Blocking_Queue)
                      return Boolean;

   function Available (Self : Protected_Blocking_Queue) return Natural;

private

   package Circular_Buffers is new Buffers.Ring (Element_Type);

   protected type Protected_Blocking_Queue_Impl (Size : Positive) is

      entry Push_Blocking (E : Element_Type);

      procedure Push_Non_Blocking (E : Element_Type);

      entry Pop_Blocking (E : out Element_Type);

      procedure Pop_Non_Blocking (E : out Element_Type);

      function Peek return Element_Type;

      function Length return Natural;

      function Is_Empty return Boolean;

      function Available return Natural;

   private
      Buffer : Circular_Buffers.Ring_Buffer (Size);
   end Protected_Blocking_Queue_Impl;

   type Protected_Blocking_Queue (Size : Positive) is tagged limited record
      Protected_Buffer : Protected_Blocking_Queue_Impl (Size);
   end record;

end Buffers.Protected_Blocking_Queue;
