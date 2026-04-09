with Runtime.Main_Loop;
with SDL.Log; use SDL.Log;
with SDL.Timers;

with System;

package body Audio.IO is

   Source_Frame_Bytes : constant Positive := Stereo_Sample'Size / System.Storage_Unit;
   Minimum_Queued_Producer_Chunks : constant Positive := 16;
   Desired_Max_Queued_Device_Buffers : constant Positive := 4;

   function Ceil_Div
     (Dividend : Long_Long_Integer;
      Divisor  : Long_Long_Integer) return Long_Long_Integer;

   function Ceil_Div
     (Dividend : Long_Long_Integer;
      Divisor  : Long_Long_Integer) return Long_Long_Integer is
   begin
      return (Dividend + Divisor - 1) / Divisor;
   end Ceil_Div;

   function Queue_Byte_Length (Frame_Count : Natural) return Natural is
     (Frame_Count * Source_Frame_Bytes);

   function Source_Bytes_For_Output_Frames
     (Output_Frames    : Natural;
      Output_Frequency : SDL.Audio.Sample_Rate) return Natural;

   function Source_Bytes_For_Output_Frames
     (Output_Frames    : Natural;
      Output_Frequency : SDL.Audio.Sample_Rate) return Natural
   is
      Source_Frames : constant Long_Long_Integer :=
        Ceil_Div
          (Dividend =>
             Long_Long_Integer (Output_Frames) *
             Long_Long_Integer (Samples_Second),
           Divisor  => Long_Long_Integer (Output_Frequency));
   begin
      return Natural (Source_Frames * Long_Long_Integer (Source_Frame_Bytes));
   end Source_Bytes_For_Output_Frames;

   procedure Wait_For_Queue_Capacity
     (Self           : in Instance;
      Incoming_Bytes : in Natural);

   procedure Wait_For_Queue_Capacity
     (Self           : in Instance;
      Incoming_Bytes : in Natural)
   is
      Queued_Bytes : Natural;
   begin
      if not Self.Is_Created or else Incoming_Bytes = 0 then
         return;
      end if;

      loop
         Queued_Bytes := Self.Playback_Stream.Queued_Bytes;

         exit when Queued_Bytes <= Self.Max_Queued_Bytes
           and then Incoming_Bytes <= Self.Max_Queued_Bytes - Queued_Bytes;

         SDL.Timers.Wait_Delay (1);
      end loop;
   end Wait_For_Queue_Capacity;

   procedure Create (Self : aliased out Instance) is
      Requested_Spec : constant SDL.Audio.Spec :=
        (Format    => SDL.Audio.Sample_Formats.Sample_Format_S16,
         Channels  => 2,
         Frequency => SDL.Audio.Sample_Rate (Samples_Second));

      Device_Buffer_Bytes : Natural;
   begin
      Self.Playback_Stream.Open
        (Application   => Requested_Spec,
         Output        => Self.Output_Spec,
         Sample_Frames => Self.Device_Sample_Frames);

      Device_Buffer_Bytes :=
        Source_Bytes_For_Output_Frames
          (Output_Frames    =>
             Natural'Max
               (Self.Device_Sample_Frames * Desired_Max_Queued_Device_Buffers,
                1),
           Output_Frequency => Self.Output_Spec.Frequency);

      Self.Max_Queued_Bytes :=
        Natural'Max
          (Device_Buffer_Bytes,
           Queue_Byte_Length
             (Runtime.Main_Loop.Producer_Chunk_Samples *
              Minimum_Queued_Producer_Chunks));

      Self.Playback_Stream.Resume;
      Self.Is_Created := True;

      Put_Info
        ("Audio output ready:" &
         " input=" & Integer (Requested_Spec.Frequency)'Img & " Hz" &
         " output=" & Integer (Self.Output_Spec.Frequency)'Img & " Hz" &
         " channels=" & Integer (Self.Output_Spec.Channels)'Img &
         " device_frames=" & Integer (Self.Device_Sample_Frames)'Img);
   exception
      when others =>
         Self.Playback_Stream.Close;
         Self.Device_Sample_Frames := 0;
         Self.Max_Queued_Bytes := 0;
         Self.Is_Created := False;
         raise;
   end Create;

   procedure Queue_Asynchronously (Self : in out Instance) is
      Buffer      : aliased Stereo_Sample_Buffer (Runtime.Main_Loop.Producer_Chunk_Samples);
      Samples     : Audio_Buffer_Access;
      Frame_Count : Natural;
   begin
      Buffer.Set_Length (Buffer.Capacity);
      Samples := Data_Access (Buffer'Access);
      Generate (Samples, Frame_Count);
      Buffer.Set_Length (Frame_Count);

      if not Self.Is_Created or else Frame_Count = 0 then
         return;
      end if;

      declare
         Byte_Length : constant Natural := Queue_Byte_Length (Frame_Count);
      begin
         Wait_For_Queue_Capacity (Self, Byte_Length);
         Self.Playback_Stream.Put
           (Data        => Samples.all (Samples.all'First)'Address,
            Byte_Length => Positive (Byte_Length));
      end;
   end Queue_Asynchronously;

   overriding
   procedure Finalize (Self : in out Instance) is
   begin
      Shutdown (Self);
   end Finalize;

   procedure Shutdown (Self : in out Instance) is
   begin
      if Self.Is_Created then
         begin
            Self.Playback_Stream.Pause;
         exception
            when others =>
               null;
         end;
      end if;

      Self.Playback_Stream.Close;
      Self.Device_Sample_Frames := 0;
      Self.Max_Queued_Bytes := 0;
      Self.Is_Created := False;
   end Shutdown;

end Audio.IO;
