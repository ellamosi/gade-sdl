with Ada.Text_IO;
with Ada.Exceptions; use Ada.Exceptions;

package body Audio.Callback is

   function Create
     (Ring : Ring_Buffer_Access)
      return Callback_Context_Access
   is
      Result : constant Callback_Context_Access := new Callback_Context;
   begin
      Result.Output_Ring := Ring;
      return Result;
   end Create;

   procedure Set_Spec
     (Context : in out Callback_Context;
      Spec    : Obtained_Spec)
   is
      Callback_Samples : constant Natural := Natural (Spec.Samples);
      Frequency        : constant Integer := Integer (Spec.Frequency);
   begin
      if Frequency > 0 then
         Context.Output_Frequency := Positive (Frequency);
      else
         Context.Output_Frequency := Default_Output_Frequency;
      end if;

      Context.Margin_Low  := Natural'Max (Callback_Samples * 2, 1);
      Context.Margin_High := Positive (Natural'Max (Context.Margin_Low + 1,
                                                   Callback_Samples * 6));
      Context.Margin_Frames := Positive (Context.Margin_High - Context.Margin_Low);
   end Set_Spec;

   function User_Data (Context : aliased in out Callback_Context)
                       return User_Data_Access is
   begin
      return Context'Unchecked_Access;
   end User_Data;

   function Callback (Context : aliased in out Callback_Context)
                      return Audio_Callback is
      pragma Unreferenced (Context);
   begin
      return SDL_Callback'Access;
   end Callback;

   function Level (Context : Callback_Context) return Float is
      Length : Natural;
   begin
      if Context.Output_Ring = null then
         return 0.5;
      end if;

      Length := Context.Output_Ring.Length;
      return
        (if Length <= Context.Margin_Low then 0.0
         elsif Length >= Context.Margin_High then 1.0
         else Float (Length - Context.Margin_Low) /
           Float (Context.Margin_Frames));
   end Level;

   procedure SDL_Callback
     (User_Data : User_Data_Access;
      Buffer    : out Bounded_Float_Buffers.Data_Container)
   is
      Context : constant Callback_Context_Access :=
        Callback_Context_Access (User_Data);

      Cursor : Cursor_Ring_Frame_Buffers.Read_Cursor;
      Buffer_Index : Positive := Buffer'First;
   begin
      if Context.Output_Ring /= null then
         Context.Output_Ring.Begin_Read (Cursor);

         while Cursor.Has_Element and Buffer_Index <= Buffer'Last loop
            Cursor.Pop (Buffer (Buffer_Index));
            Buffer_Index := Buffer_Index + 1;
         end loop;

         Cursor.Commit_Read;
      end if;

      if Buffer_Index <= Buffer'Last then
         Write_Silence (Buffer (Buffer_Index .. Buffer'Last));
      end if;
   exception
      when E : others =>
         Ada.Text_IO.Put_Line ("Callback Exception");
         Ada.Text_IO.Put_Line (Exception_Message (E));
   end SDL_Callback;

   procedure Write_Silence (Buffer : out Bounded_Float_Buffers.Data_Container) is
   begin
      Buffer := (others => (0.0, 0.0));
   end Write_Silence;

   function Output_Frequency (Context : Callback_Context) return Positive
   is (Context.Output_Frequency);

end Audio.Callback;
