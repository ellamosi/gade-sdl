with Ada.Finalization;
with SDL.Audio;
with SDL.Audio.Sample_Formats;
with SDL.Audio.Streams;

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
   type Instance is new Ada.Finalization.Limited_Controlled with record
      Playback_Stream      : SDL.Audio.Streams.Stream;
      Output_Spec          : SDL.Audio.Spec :=
        (Format    => SDL.Audio.Sample_Formats.Unknown,
         Channels  => 2,
         Frequency => 48_000);
      Device_Sample_Frames : Natural := 0;
      Max_Queued_Bytes     : Natural := 0;
      Is_Created           : Boolean := False;
   end record;

end Audio.IO;
