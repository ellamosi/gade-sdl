with SDL.Log; use SDL.Log;

with Interfaces;
with Interfaces.C;

with Ada.Text_IO;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Unchecked_Deallocation;

with Audio.Resamplers;
with Gade_Runner;

package body Audio.IO is

   procedure Free is new Ada.Unchecked_Deallocation
     (Object => Callback_Context,
      Name   => Callback_Context_Access);

   Max_Delta : constant Float := 0.005;

   --  Simple PI controller that drives ring fill-level toward 0.5.
   Proportional_Gain : constant Float := 0.008;
   Integral_Gain     : constant Float := 0.0002;
   Integral_Limit    : constant Float := 10.0;

   function Clamp
     (Value : Float;
      Min   : Float;
      Max   : Float) return Float;

   function Clamp
     (Value : Float;
      Min   : Float;
      Max   : Float) return Float
   is
   begin
      return Float'Max (Min, Float'Min (Max, Value));
   end Clamp;

   procedure Create (Self : aliased out Instance) is
      Device   : Devices.Device renames Self.Device;
      Requested : constant Desired_Spec :=
        (Mode      => Desired,
         Frequency => Interfaces.C.int (Desired_Output_Frequency),
         Format    => Sample_Format,
         Channels  => Desired_Channel_Count,
         Samples   => Interfaces.Unsigned_16 (Desired_Callback_Frames));
      Obtained : Obtained_Spec renames Self.Spec;
      Callback  : Audio_Callback;
      User_Data : User_Data_Access;

      Min_Buffer_Count : Positive;
   begin
      Self.Callback_Context := Create (Self.Ring'Unchecked_Access,
                                       Self.Free_Queue'Unchecked_Access,
                                       Self.Busy_Queue'Unchecked_Access);
      Callback := Self.Callback_Context.Callback;
      User_Data := Self.Callback_Context.User_Data;

      Put_Debug ("Desired - Frequency :" & Requested.Frequency'Img);
      Put_Debug ("Desired - Format/Bit_Size :" & Requested.Format.Bit_Size'Img);
      Put_Debug ("Desired - Format/Float :" & Requested.Format.Float'Img);
      Put_Debug ("Desired - Format/Big_Endian :" & Requested.Format.Endianness'Img);
      Put_Debug ("Desired - Format/Signed :" & Requested.Format.Signed'Img);
      Put_Debug ("Desired - Channels :" & Requested.Channels'Img);
      Put_Debug ("Desired - Samples :" & Requested.Samples'Img);

      Put_Debug ("Opening Default Device");

      Open (Device,
            Callback  => Callback,
            User_Data => User_Data,
            Desired   => Requested,
            Obtained  => Obtained);
      Self.Is_Created := True;
      Self.Is_Shutdown := False;

      Put_Debug ("Opened Device:" & Device.Get_ID'Img);
      Put_Debug ("Device Status: " & Device.Get_Status'Img);

      Put_Debug ("Obtained - Frequency :" & Obtained.Frequency'Img);
      Put_Debug ("Obtained - Format/Bit_Size :" & Obtained.Format.Bit_Size'Img);
      Put_Debug ("Obtained - Format/Float : " & Obtained.Format.Float'Img);
      Put_Debug ("Obtained - Format/Endianness : " & Obtained.Format.Endianness'Img);
      Put_Debug ("Obtained - Format/Signed : " & Obtained.Format.Signed'Img);
      Put_Debug ("Obtained - Channels :" & Obtained.Channels'Img);
      Put_Debug ("Obtained - Samples :" & Obtained.Samples'Img);
      Put_Debug ("Obtained - Silence :" & Obtained.Silence'Img);
      Put_Debug ("Obtained - Size :" & Obtained.Size'Img);

      Self.Callback_Context.Set_Spec (Obtained);

      Min_Buffer_Count :=
        (Positive (Obtained.Samples) - 1) /
          Min_Resampled_Block_Length (Self.Callback_Context.all) + 1;
      Put_Debug ("Min_Buffer_Count :" & Min_Buffer_Count'Img);

      for Frame_Buffer of Self.Frame_Buffers loop
         Self.Free_Queue.Push_Non_Blocking (Frame_Buffer'Unchecked_Access);
      end loop;

      Self.Resampler.Start (Self.Callback_Context,
                            Self.Ring'Unchecked_Access,
                            Self.Free_Queue'Unchecked_Access,
                            Self.Busy_Queue'Unchecked_Access);

      Self.Device.Pause (False);
   end Create;

   task body Resampling_Task is
      CC         : Callback_Context_Access;
      Ring       : Ring_Buffer_Access;
      Free_Queue : Free_Frame_Buffer_Access;
      Busy_Queue : Busy_Frame_Buffer_Access;
      Buffer     : Bounded_Buffer_Access;

      Resampler      : Audio.Resamplers.Resampler;
      Integral_Error : Float := 0.0;
   begin
      accept Start
        (CC         : Callback_Context_Access;
         Ring       : Ring_Buffer_Access;
         Free_Queue : Free_Frame_Buffer_Access;
         Busy_Queue : Busy_Frame_Buffer_Access)
      do
         Resampling_Task.CC         := CC;
         Resampling_Task.Ring       := Ring;
         Resampling_Task.Free_Queue := Free_Queue;
         Resampling_Task.Busy_Queue := Busy_Queue;
      end Start;

      Resampler.Reset
        (Float (Gade.Audio_Buffer.Samples_Frame * Gade_Runner.Max_Frame_Rendering_Rate),
         Float (Audio.Callbacks.Output_Frequency (CC.all)));

      loop
         Busy_Queue.Pop_Blocking (Buffer);

         declare
            Fill                 : constant Float := Level (CC.all);
            Error                : constant Float := Fill - 0.5;
            Dynamic_Delta        : Float;
            Dynamic_Frequency    : Float;
            Base_Input_Frequency : constant Float :=
              Float (Natural'Max (Buffer.Length, 1) * Gade_Runner.Max_Frame_Rendering_Rate);

            Resampled_Capacity : constant Positive :=
              Positive
                (Natural'Max
                   (Natural
                      (Float
                         (Buffer.Length *
                            Audio.Callbacks.Output_Frequency (CC.all)) /
                       (Base_Input_Frequency * (1.0 - Max_Delta))) + 8,
                    1));
            Resampled : Circular_Float_Buffers.Circular_Buffer
              (Resampled_Capacity);
            Frame : Float_Frame;
            Cursor : Cursor_Ring_Frame_Buffers.Write_Cursor;
         begin
            Integral_Error := Clamp (Integral_Error + Error,
                                     -Integral_Limit,
                                     Integral_Limit);

            Dynamic_Delta := Clamp (Error * Proportional_Gain +
                                    Integral_Error * Integral_Gain,
                                    -Max_Delta,
                                    Max_Delta);
            Dynamic_Frequency :=
              Base_Input_Frequency * (1.0 + Dynamic_Delta);

            Resampler.Set_Input_Frequency (Dynamic_Frequency);
            Resampler.Resample (Buffer.all, Resampled);

            Ring.Begin_Write (Cursor);
            while Cursor.Has_Element and not Resampled.Is_Empty loop
               Resampled.Pop (Frame);
               Cursor.Push (Frame);
            end loop;
            Cursor.Commit_Write;
         end;

         Free_Queue.Push_Blocking (Buffer);
      end loop;
   exception
      when E : others =>
         Ada.Text_IO.Put_Line ("Resampling Task Exception");
         Ada.Text_IO.Put_Line (Exception_Message (E));
   end Resampling_Task;

   procedure Queue_Asynchronously (Self : in out Instance) is
      Buffer      : Bounded_Buffer_Access;
      Frame_Count : Natural;

      Buffer_Available : Boolean;
   begin
      Buffer_Available := not Self.Free_Queue.Is_Empty;

      if Buffer_Available then
         Self.Free_Queue.Pop_Blocking (Buffer);
      else
         Buffer := Self.Dummy_Buffer'Unrestricted_Access;
      end if;

      Buffer.Set_Length (Buffer.Capacity);
      Generate (Data_Access (Buffer), Frame_Count);
      Buffer.Set_Length (Frame_Count);

      if Buffer_Available then
         if Self.Busy_Queue.Available > 0 then
            Self.Busy_Queue.Push_Non_Blocking (Buffer);
         else
            --  Keep latency bounded by dropping producer blocks when saturated.
            Self.Free_Queue.Push_Non_Blocking (Buffer);
         end if;
      end if;
   end Queue_Asynchronously;

   overriding
   procedure Finalize (Self : in out Instance) is
   begin
      Shutdown (Self);
   end Finalize;

   procedure Shutdown (Self : in out Instance) is
   begin
      if not Self.Is_Created or else Self.Is_Shutdown then
         return;
      end if;

      Put_Debug ("Audio Finalize");
      Self.Device.Pause (True);
      Self.Device.Close;
      abort Self.Resampler;
      if Self.Callback_Context /= null then
         Free (Self.Callback_Context);
      end if;
      Self.Is_Shutdown := True;
   end Shutdown;

end Audio.IO;
