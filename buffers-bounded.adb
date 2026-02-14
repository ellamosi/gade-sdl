with Ada.Unchecked_Conversion;

package body Buffers.Bounded is

   procedure Clear (Self : out Bounded_Buffer) is
   begin
      Self.Set_Length (0);
   end Clear;

   procedure Set_Length (Self : in out Bounded_Buffer; Count : Natural) is
   begin
      Self.Slice (Upper) := Count;
   end Set_Length;

   function Length (Self : Bounded_Buffer) return Natural is
   begin
      return Self.Slice (Upper);
   end Length;

   function Is_Empty (Self : Bounded_Buffer) return Boolean is
   begin
      return Length (Self) = 0;
   end Is_Empty;

   procedure Append (Self : in out Bounded_Buffer; E : Element_Type) is
   begin
      Self.Slice (Upper) := Self.Slice (Upper) + 1;
      Self.Data (Self.Slice (Upper)) := E;
   end Append;

   function Element (Self : Bounded_Buffer; Index : Positive)
                     return Element_Type
   is
   begin
      return Self.Data (Index);
   end Element;

   function Data_Access (Self : in out Bounded_Buffer)
                         return Data_Container_Access
   is
      --  This is quite the hack, but it all stems for the inability to obtain
      --  proper fat pointers to Ada slices through the 'Access attribute.
      --  This approach is adapted from the answer by Simon Wright in here:
      --  https://stackoverflow.com/questions/15476403/return-a-fat-thick-pointer-as-an-out-parameter
      --  Hopefully a future language revision makes this unnecessary.
      type Bounds_Access is access all Bounds;

      type Fat_Pointer is record
         Data   : System.Address;
         Bounds : Bounds_Access;
      end record;
      for Fat_Pointer use record
         Data   at Address_Size_Bytes * 0 range 0 .. Address_Size_Bits - 1;
         Bounds at Address_Size_Bytes * 1 range 0 .. Address_Size_Bits - 1;
      end record;

      pragma Warnings (Off, "possible aliasing problem for type*");
      function Data_Container_Access
      is new Ada.Unchecked_Conversion (Fat_Pointer, Data_Container_Access);
      pragma Warnings (On);
   begin
      return Data_Container_Access
        ((Bounds => Self.Slice'Access,
          Data   => Self.Data (1)'Address));
   end Data_Access;

   function Has_Element (Position : Cursor) return Boolean is
   begin
      return Position.Index <= Position.Last;
   end Has_Element;

   overriding
   function First (Object : Iterator) return Cursor is
   begin
      return (Object.Last, Object.First);
   end First;

   overriding
   function Next (Object : Iterator; Position : Cursor) return Cursor is
   begin
      return (Object.Last, Position.Index + 1);
   end Next;

   function Iterate (Container : Bounded_Buffer)
                     return Iterators.Forward_Iterator'Class is
   begin
      return Iterator'(1, Container.Length);
   end Iterate;

   function Constant_Reference (Container : aliased in Bounded_Buffer;
                                Index     : Positive)
                                return Constant_Reference_Type is
   begin
      return (Element => Container.Data (Index)'Access);
   end Constant_Reference;

   function Constant_Reference (Container : aliased in Bounded_Buffer;
                                Position  : Cursor)
                                return Constant_Reference_Type is
   begin
      return Constant_Reference (Container, Position.Index);
   end Constant_Reference;

   function Reference (Container : aliased in out Bounded_Buffer;
                       Index     : Positive)
                       return Reference_Type is
   begin
      return (Element => Container.Data (Index)'Access);
   end Reference;

   function Reference (Container : aliased in out Bounded_Buffer;
                       Position  : in Cursor)
                       return Reference_Type is
   begin
      return Reference (Container, Position.Index);
   end Reference;

end Buffers.Bounded;
