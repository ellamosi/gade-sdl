package body Buffers.Blocking_Queue is

   procedure Push_Blocking
     (Self : in out Protected_Blocking_Queue;
      E    : Element_Type)
   is
   begin
      Self.Protected_Buffer.Push_Blocking (E);
   end Push_Blocking;

   procedure Push_Non_Blocking
     (Self : in out Protected_Blocking_Queue;
      E    : Element_Type)
   is
   begin
      Self.Protected_Buffer.Push_Non_Blocking (E);
   end Push_Non_Blocking;

   procedure Pop_Blocking
     (Self : in out Protected_Blocking_Queue;
      E    : out Element_Type)
   is
   begin
      Self.Protected_Buffer.Pop_Blocking (E);
   end Pop_Blocking;

   procedure Pop_Non_Blocking
     (Self : in out Protected_Blocking_Queue;
      E    : out Element_Type)
   is
   begin
      Self.Protected_Buffer.Pop_Non_Blocking (E);
   end Pop_Non_Blocking;

   function Peek (Self : Protected_Blocking_Queue) return Element_Type is
   begin
      return Self.Protected_Buffer.Peek;
   end Peek;

   function Length (Self : Protected_Blocking_Queue) return Natural is
   begin
      return Self.Protected_Buffer.Length;
   end Length;

   function Is_Empty (Self : Protected_Blocking_Queue) return Boolean is
   begin
      return Self.Protected_Buffer.Is_Empty;
   end Is_Empty;

   function Available (Self : Protected_Blocking_Queue) return Natural is
   begin
      return Self.Protected_Buffer.Available;
   end Available;

   protected body Protected_Blocking_Queue_Impl is

      entry Push_Blocking (E : Element_Type) when Buffer.Available > 0 is
      begin
         Buffer.Push (E);
      end Push_Blocking;

      procedure Push_Non_Blocking (E : Element_Type) is
      begin
         Buffer.Push (E);
      end Push_Non_Blocking;

      entry Pop_Blocking (E : out Element_Type) when not Is_Empty is
      begin
         Buffer.Pop (E);
      end Pop_Blocking;

      procedure Pop_Non_Blocking (E : out Element_Type) is
      begin
         Buffer.Pop (E);
      end Pop_Non_Blocking;

      function Peek return Element_Type is
      begin
         return Buffer.Peek;
      end Peek;

      function Length return Natural is
      begin
         return Buffer.Length;
      end Length;

      function Is_Empty return Boolean is
      begin
         return Buffer.Is_Empty;
      end Is_Empty;

      function Available return Natural is
      begin
         return Buffer.Available;
      end Available;

   end Protected_Blocking_Queue_Impl;

end Buffers.Blocking_Queue;
