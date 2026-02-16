with SDL.Timers; use SDL.Timers;

generic
   with procedure Display_FPS (Value : Float);
package Runtime.Frame_Pacing is

   type Frame_Timer is tagged private;

   procedure Reset (Self : out Frame_Timer);

   procedure Time_Frame (Self : in out Frame_Timer);

   procedure Delay_Until_Next (Self : in out Frame_Timer);

private

   Target_Frame_Rate : constant := 60;
   Ticks_Per_Frame   : constant Milliseconds := 1000 / Target_Frame_Rate;

   Min_Ticks_Per_FPS_Sample : constant := 1000;

   type FPS_Sampler is tagged record
      Frame_Count : Natural;
      Next_Update : Milliseconds;
      Last_Update : Milliseconds;
   end record;

   procedure Reset (Self      : out FPS_Sampler;
                    Now_Ticks : Milliseconds);

   procedure Sample_Frame (Self      : in out FPS_Sampler;
                           Now_Ticks : Milliseconds);

   type Frame_Timer is tagged record
      FPS_Sampler : Runtime.Frame_Pacing.FPS_Sampler;
      Frame_Ticks : Milliseconds;
   end record;

end Runtime.Frame_Pacing;
