with SDL.Timers;

package Runtime is

   --  Shared timing settings used by Runtime subpackages.
   Target_Frame_Rate : constant Positive := 60;
   Ticks_Per_Second  : constant Positive := 1_000;

   Ticks_Per_Frame : constant SDL.Timers.Milliseconds_Long :=
     SDL.Timers.Milliseconds_Long (Ticks_Per_Second / Target_Frame_Rate);

end Runtime;
