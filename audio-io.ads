private with Audio.Callbacks;

with SDL.Audio.Sample_Formats;

with Ada.Finalization;
with System;

package Audio.IO is

   type Instance is new Ada.Finalization.Limited_Controlled with private;

   procedure Create (Self : aliased out Instance);

   procedure Shutdown (Self : in out Instance);

   generic
      with procedure Generate (Buffer : Audio_Buffer_Access;
                               Count  : out Natural);
   procedure Queue_Asynchronously (Self : in out Instance);

   overriding
   procedure Finalize (Self : in out Instance);

private
   use Audio.Callbacks, Devices;

   Desired_Output_Frequency : constant Positive := 48_000;
   --  Hz
   --  Just a suggestion. Actual frequency supported by system might vary.

   Desired_Channel_Count : constant := 2;
   --  Stereo!

   Desired_Callback_Frames : constant Positive := 512;
   --  ~10.67 ms of samples
   --  How big should the SDL audio callback buffer be. Has to be a power of
   --  two. Bigger values reduce the chances of buffer underruns (which would
   --  cause short audio interruptions) but increase latency.

   type Frame_Buffer_Array is array (1 .. Frame_Buffer_Count)
     of aliased Video_Frame_Sample_Buffer;

   Queue_Capacity : constant Positive := Frame_Buffer_Count;
   Ring_Capacity  : constant Positive := Desired_Callback_Frames * 8;

   task type Resampling_Task is
      entry Start
        (CC         : Callback_Context_Access;
         Ring       : Ring_Buffer_Access;
         Free_Queue : Free_Frame_Buffer_Access;
         Busy_Queue : Busy_Frame_Buffer_Access);
   end Resampling_Task;

   type Instance is new Ada.Finalization.Limited_Controlled with record
      Device : Devices.Device;
      Spec   : Obtained_Spec;

      Dummy_Buffer  : aliased Video_Frame_Sample_Buffer;
      Frame_Buffers : Frame_Buffer_Array;

      Free_Queue : aliased Blocking_Frame_Buffers.Protected_Circular_Buffer (Queue_Capacity);
      Busy_Queue : aliased Blocking_Frame_Buffers.Protected_Circular_Buffer (Queue_Capacity);

      Ring : aliased Cursor_Ring_Frame_Buffers.Protected_Circular_Buffer (Ring_Capacity);

      Resampler : Resampling_Task;

      Callback_Context : Callback_Context_Access;
      Is_Created       : Boolean := False;
      Is_Shutdown      : Boolean := False;
   end record;

   Sample_Format : constant SDL.Audio.Sample_Formats.Sample_Format :=
     SDL.Audio.Sample_Formats.Sample_Format_F32LSB;

   Frame_Size_Bytes : constant Natural :=
     Natural (Sample_Format.Bit_Size) * Desired_Channel_Count / System.Storage_Unit;

end Audio.IO;
