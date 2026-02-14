with Ada.Text_IO;

with GNAT.Traceback.Symbolic;

with Gade.Interfaces; use Gade.Interfaces;

with Audio.IO;     use Audio.IO;
with Gade_Runner;  use Gade_Runner;
with Gade_Window;  use Gade_Window;
with Gade_Input;   use Gade_Input;
with Command_Line; use Command_Line;
with Frame_Timers;

with SDL.Log; use SDL.Log;

with Ada.Exceptions; use Ada.Exceptions;

procedure Gade_Main is
   --  use GNAT.Traceback;
   --  use GNAT.Traceback.Symbolic;

   G        : Gade_Type;
   Window   : Gade_Window_Type;
   Audio_IO : Audio.IO.Instance;
   Input    : aliased Gade_Input.Instance;
   Runner   : Gade_Runner.Instance;
   CLI      : Command_Line.Instance;

   Limit_FPS : Boolean;

   procedure Display_FPS (Value : Float);
   procedure Display_FPS (Value : Float) is
   begin
      Window.Set_FPS (Value);
   end Display_FPS;

   package Window_FPS_Frame_Timers is new Frame_Timers (Display_FPS);

   Frame_Timer : Window_FPS_Frame_Timers.Frame_Timer;

   procedure Wait_Loop;
   procedure Wait_Loop is
   begin
      while not Input.Quit and not Input.File_Dropped loop
         Input.Wait;
      end loop;
   end Wait_Loop;

   procedure Render_Loop (ROM_Filename : String);
   procedure Render_Loop (ROM_Filename : String) is
   begin
      Put_Debug ("Loading ROM");
      Load_ROM (G, ROM_Filename);
      Reset (G);

      Frame_Timer.Reset;

      while not Input.Quit and not Input.File_Dropped loop
         Frame_Timer.Time_Frame;

         Step (Runner, G, Window, Audio_IO);

         Input.Poll;

         Limit_FPS := Limit_FPS or Input.Fast_Forward;
         if Limit_FPS and not Input.Fast_Forward then
            Frame_Timer.Delay_Until_Next;
         end if;
      end loop;
   end Render_Loop;
begin
   if not SDL.Initialise then raise Program_Error; end if;

   Parse (CLI);

   SDL.Log.Set (Category => SDL.Log.Application, Priority => CLI.Log_Priority);

   Limit_FPS := not CLI.Uncapped_FPS;

   Create (Window);
   Create (Audio_IO);
   Create (Input);
   Create (Runner);

   Put_Debug ("Initializing libgade");
   Create (G);
   Put_Debug ("Setting up input handling");
   Set_Input_Reader (G, Input'Access);

   while not Input.Quit loop
      if CLI.ROM_Filename /= "" then
         Render_Loop (CLI.ROM_Filename);
      elsif Input.File_Dropped then
         declare
            Filename : constant String := Input.Dropped_Filename;
         begin
            Input.Clear_Dropped_File;
            Render_Loop (Filename);
         end;
      else
         Wait_Loop;
      end if;
   end loop;

   --  Local resources are controlled and will get automatically finalized

   Shutdown (Audio_IO);
   Shutdown (Window);
   SDL.Finalise;
exception
   when E : others =>
      Ada.Text_IO.Put_Line ("Main Thread Exception");
      Ada.Text_IO.Put_Line (Exception_Message (E));
      Ada.Text_IO.Put_Line (GNAT.Traceback.Symbolic.Symbolic_Traceback (E));
end Gade_Main;
