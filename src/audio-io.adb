with SDL.Log; use SDL.Log;

with Interfaces;
with Interfaces.C;

with Ada.Text_IO;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Unchecked_Deallocation;

with Audio.Resampler;
with Runtime.Main_Loop;

package body Audio.IO is

   procedure Free is new Ada.Unchecked_Deallocation
     (Object => Callback_Context,
      Name   => Callback_Context_Access);

   protected Stats is
      procedure Reset;
      procedure Add_Producer_Samples (Count : Natural);
      procedure Increment_Produced_Block;
      procedure Observe_Source_Ring (Ring_Length : Natural);
      procedure Observe_Output_Ring (Ring_Length : Natural);
      procedure Report;
   private
      Producer_Samples : Long_Long_Integer := 0;
      Produced_Blocks  : Natural := 0;

      Source_Ring_Seen : Boolean := False;
      Source_Ring_Min  : Natural := 0;
      Source_Ring_Max  : Natural := 0;

      Output_Ring_Seen : Boolean := False;
      Output_Ring_Min  : Natural := 0;
      Output_Ring_Max  : Natural := 0;
   end Stats;

   protected body Stats is
      procedure Reset is
      begin
         Producer_Samples := 0;
         Produced_Blocks  := 0;
         Source_Ring_Seen := False;
         Output_Ring_Seen := False;
      end Reset;

      procedure Add_Producer_Samples (Count : Natural) is
      begin
         Producer_Samples := Producer_Samples + Long_Long_Integer (Count);
      end Add_Producer_Samples;

      procedure Increment_Produced_Block is
      begin
         Produced_Blocks := Produced_Blocks + 1;
      end Increment_Produced_Block;

      procedure Observe_Source_Ring (Ring_Length : Natural) is
      begin
         if not Source_Ring_Seen then
            Source_Ring_Seen := True;
            Source_Ring_Min := Ring_Length;
            Source_Ring_Max := Ring_Length;
         else
            Source_Ring_Min := Natural'Min (Source_Ring_Min, Ring_Length);
            Source_Ring_Max := Natural'Max (Source_Ring_Max, Ring_Length);
         end if;
      end Observe_Source_Ring;

      procedure Observe_Output_Ring (Ring_Length : Natural) is
      begin
         if not Output_Ring_Seen then
            Output_Ring_Seen := True;
            Output_Ring_Min := Ring_Length;
            Output_Ring_Max := Ring_Length;
         else
            Output_Ring_Min := Natural'Min (Output_Ring_Min, Ring_Length);
            Output_Ring_Max := Natural'Max (Output_Ring_Max, Ring_Length);
         end if;
      end Observe_Output_Ring;

      procedure Report is
      begin
         Put_Info
           ("Audio Stats: samples=" & Producer_Samples'Img &
              " blocks=" & Produced_Blocks'Img);

         if Source_Ring_Seen then
            Put_Info
              ("Audio Source Ring Stats: len[min,max]=" &
                 Source_Ring_Min'Img & "," & Source_Ring_Max'Img);
         end if;

         if Output_Ring_Seen then
            Put_Info
              ("Audio Ring Stats: len[min,max]=" &
                 Output_Ring_Min'Img & "," & Output_Ring_Max'Img);
         end if;
      end Report;
   end Stats;

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
      Device_Opened     : Boolean := False;

      procedure Cleanup_On_Failure;
      procedure Cleanup_On_Failure is
      begin
         if Device_Opened then
            begin
               Self.Device.Pause (True);
            exception
               when others =>
                  null;
            end;
         end if;

         if Device_Opened then
            begin
               Self.Device.Close;
            exception
               when others =>
                  null;
            end;
         end if;

         if Self.Callback_Context /= null then
            Free (Self.Callback_Context);
            Self.Callback_Context := null;
         end if;

         Self.Is_Created := False;
         Self.Is_Shutdown := False;
      end Cleanup_On_Failure;
   begin
      Stats.Reset;

      Self.Callback_Context := Create (Self.Ring'Unchecked_Access);
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
            Obtained  => Obtained,
            Allowed_Changes => Devices.Frequency or Devices.Samples);
      Device_Opened := True;

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
      Stats.Observe_Source_Ring (Self.Source_Ring.Length);

      Self.Resampler.Start (Self.Callback_Context,
                            Self.Source_Ring'Unchecked_Access,
                            Self.Ring'Unchecked_Access);

      Self.Device.Pause (False);
   exception
      when E : Devices.Audio_Device_Error =>
         if not Device_Opened then
            Put_Info ("Audio open failed: " & Exception_Message (E));
            Put_Info ("Audio disabled: no supported output format/device");
            Cleanup_On_Failure;
            return;
         end if;
         Cleanup_On_Failure;
         raise;
      when others =>
         Cleanup_On_Failure;
         raise;
   end Create;

   task body Resampling_Task is
      CC          : Callback_Context_Access;
      Source_Ring : Source_Ring_Buffer_Access;
      Ring        : Ring_Buffer_Access;

      Resampler      : Audio.Resampler.Resampler;
      Integral_Error : Float := 0.0;
   begin
      select
         accept Start
           (CC          : Callback_Context_Access;
            Source_Ring : Source_Ring_Buffer_Access;
            Ring        : Ring_Buffer_Access)
         do
            Resampling_Task.CC := CC;
            Resampling_Task.Source_Ring := Source_Ring;
            Resampling_Task.Ring := Ring;
         end Start;
      or
         terminate;
      end select;

      Resampler.Reset
        (Float (Gade.Audio_Buffer.Samples_Second),
         Float (Audio.Callback.Output_Frequency (CC.all)));

      loop
         select
            accept Stop;
            exit;
         else
            null;
         end select;

         declare
            Source_Cursor : Cursor_Ring_Stereo_Samples.Read_Cursor;
            Input_Block   : Stereo_Sample_Buffer (Runtime.Main_Loop.Producer_Chunk_Samples);
            Input_Count   : Natural := 0;
            Sample        : Stereo_Sample;
         begin
            Source_Ring.Begin_Read (Source_Cursor);
            while Source_Cursor.Has_Element and then Input_Count < Input_Block.Capacity loop
               Source_Cursor.Pop (Sample);
               Input_Count := Input_Count + 1;
               Input_Block (Input_Count) := Sample;
            end loop;
            Source_Cursor.Commit_Read;

            Stats.Observe_Source_Ring (Source_Ring.Length);

            if Input_Count = 0 then
               delay 0.001;
            else
               Input_Block.Set_Length (Input_Count);

               declare
                  Fill                 : constant Float := Level (CC.all);
                  Error                : constant Float := Fill - 0.5;
                  Dynamic_Delta        : Float;
                  Dynamic_Frequency    : Float;
                  Base_Input_Frequency : constant Float :=
                    Float (Gade.Audio_Buffer.Samples_Second);

                  Resampled_Capacity : constant Positive :=
                    Positive
                      (Natural'Max
                         (Natural
                            (Float
                               (Input_Block.Length *
                                  Audio.Callback.Output_Frequency (CC.all)) /
                             (Base_Input_Frequency * (1.0 - Max_Delta))) + 8,
                          1));
                  Resampled : Circular_Float_Buffers.Ring_Buffer
                    (Resampled_Capacity);
                  Frame  : Float_Frame;
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
                  Resampler.Resample (Input_Block, Resampled);

                  Ring.Begin_Write (Cursor);
                  while Cursor.Has_Element and not Resampled.Is_Empty loop
                     Resampled.Pop (Frame);
                     Cursor.Push (Frame);
                  end loop;
                  Cursor.Commit_Write;
                  Stats.Observe_Output_Ring (Ring.Length);
               end;
            end if;
         end;
      end loop;
   exception
      when E : others =>
         Ada.Text_IO.Put_Line ("Resampling Task Exception");
         Ada.Text_IO.Put_Line (Exception_Message (E));
   end Resampling_Task;

   procedure Queue_Asynchronously (Self : in out Instance) is
      Buffer       : aliased Stereo_Sample_Buffer (Runtime.Main_Loop.Producer_Chunk_Samples);
      Frame_Count  : Natural;
      Buffer_Index : Positive := 1;
      Cursor       : Cursor_Ring_Stereo_Samples.Write_Cursor;
   begin
      Buffer.Set_Length (Buffer.Capacity);
      Generate (Data_Access (Buffer'Access), Frame_Count);
      Buffer.Set_Length (Frame_Count);

      if not Self.Is_Created or else Self.Is_Shutdown then
         return;
      end if;

      Stats.Add_Producer_Samples (Frame_Count);
      Stats.Increment_Produced_Block;

      while Buffer_Index <= Frame_Count loop
         Self.Source_Ring.Begin_Write (Cursor);
         while Cursor.Has_Element and then Buffer_Index <= Frame_Count loop
            Cursor.Push (Buffer (Buffer_Index));
            Buffer_Index := Buffer_Index + 1;
         end loop;
         Cursor.Commit_Write;
         Stats.Observe_Source_Ring (Self.Source_Ring.Length);

         if Buffer_Index <= Frame_Count then
            delay 0.001;
         end if;
      end loop;
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
      Self.Resampler.Stop;
      Stats.Report;
      if Self.Callback_Context /= null then
         Free (Self.Callback_Context);
         Self.Callback_Context := null;
      end if;
      Self.Is_Shutdown := True;
   end Shutdown;

end Audio.IO;
