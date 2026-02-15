private with Audio.Callbacks;

with SDL.Audio.Sample_Formats;

with Ada.Finalization;

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

   Source_Ring_Capacity : constant Positive := Desired_Callback_Frames * 8;
   Ring_Capacity        : constant Positive := Desired_Callback_Frames * 8;

   task type Resampling_Task is
      entry Start
        (CC          : Callback_Context_Access;
         Source_Ring : Source_Ring_Buffer_Access;
         Ring        : Ring_Buffer_Access);
      entry Stop;
   end Resampling_Task;

   type Instance is new Ada.Finalization.Limited_Controlled with record
      Device : Devices.Device;
      Spec   : Obtained_Spec;

      Source_Ring : aliased Cursor_Ring_Stereo_Samples.Transactional_Ring_Buffer (Source_Ring_Capacity);
      Ring        : aliased Cursor_Ring_Frame_Buffers.Transactional_Ring_Buffer (Ring_Capacity);

      Resampler : Resampling_Task;

      Callback_Context : Callback_Context_Access;
      Is_Created       : Boolean := False;
      Is_Shutdown      : Boolean := False;
   end record;

   Sample_Format : constant SDL.Audio.Sample_Formats.Sample_Format :=
     SDL.Audio.Sample_Formats.Sample_Format_F32LSB;

end Audio.IO;
