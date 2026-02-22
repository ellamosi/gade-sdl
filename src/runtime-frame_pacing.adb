package body Runtime.Frame_Pacing is

   procedure Reset (Self : out Frame_Timer) is
   begin
      Reset (Self.FPS_Sampler, SDL.Timers.Ticks);
   end Reset;

   procedure Time_Frame (Self : in out Frame_Timer) is
      Now_Ticks : constant Milliseconds_Long := SDL.Timers.Ticks;
   begin
      Self.FPS_Sampler.Sample_Frame (Now_Ticks);
      Self.Frame_Ticks := Now_Ticks;
   end Time_Frame;

   procedure Delay_Until_Next (Self : in out Frame_Timer) is
      Busy_Ticks : constant Milliseconds_Long := SDL.Timers.Ticks - Self.Frame_Ticks;
   begin
      if Busy_Ticks < Ticks_Per_Frame then
         SDL.Timers.Wait_Delay (Ticks_Per_Frame - Busy_Ticks);
      end if;
   end Delay_Until_Next;

   procedure Reset
     (Self      : out Runtime.Frame_Pacing.FPS_Sampler;
      Now_Ticks : Milliseconds_Long)
   is
   begin
      Self.Last_Update := Now_Ticks;
      Self.Next_Update := Now_Ticks + Ticks_Per_FPS_Sample;
      Self.Frame_Count := 0;
   end Reset;

   procedure Sample_Frame
     (Self      : in out Runtime.Frame_Pacing.FPS_Sampler;
      Now_Ticks : Milliseconds_Long)
   is
      Sampled_Ticks : Milliseconds_Long;
      FPS           : Float;
   begin
      Self.Frame_Count := Self.Frame_Count + 1;
      Sampled_Ticks := Now_Ticks - Self.Last_Update;
      if Now_Ticks > Self.Next_Update and Sampled_Ticks > 0 then
         FPS := Float (Self.Frame_Count * 1000) / Float (Sampled_Ticks);
         Display_FPS (FPS);

         Reset (Self, Now_Ticks);
      end if;
   end Sample_Frame;

end Runtime.Frame_Pacing;
