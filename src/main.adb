with Ada.Text_IO;

with GNAT.Traceback.Symbolic;

with Gade.Interfaces; use Gade.Interfaces;

with Audio.IO;            use Audio.IO;
with Runtime.Main_Loop;        use Runtime.Main_Loop;
with Video.Window;        use Video.Window;
with Input;
with Cli;
with Runtime.Frame_Pacing;

with SDL.Log; use SDL.Log;

with Ada.Exceptions; use Ada.Exceptions;

procedure Main is


   G        : Gade_Type;
   Window   : Window_Instance;
   Audio_IO : Audio.IO.Instance;
   Audio_IO : Audio.IO.Instance;
   Input_Reader : aliased Input.Instance;
   Runner   : Runtime.Main_Loop.Instance;
   Args     : Cli.Instance;

   Limit_FPS : Boolean;

   procedure Display_FPS (Value : Float);
   procedure Display_FPS (Value : Float) is
   begin
      Window.Set_FPS (Value);
   end Display_FPS;

   package Window_FPS_Frame_Timers is new Runtime.Frame_Pacing (Display_FPS);

   Frame_Timer : Window_FPS_Frame_Timers.Frame_Timer;

   procedure Wait_Loop;
   procedure Wait_Loop is
   begin
      while not Input_Reader.Quit and not Input_Reader.File_Dropped loop
         Input_Reader.Wait;
      end loop;
   end Wait_Loop;

   procedure Render_Loop (ROM_Filename : String);
   procedure Render_Loop (ROM_Filename : String) is
   begin
      Put_Debug ("Loading ROM");
      Load_ROM (G, ROM_Filename);
      Reset (G);

      Frame_Timer.Reset;

      while not Input_Reader.Quit and not Input_Reader.File_Dropped loop
         Frame_Timer.Time_Frame;

         Step (Runner, G, Window, Audio_IO);

         Input_Reader.Poll;

         Limit_FPS := Limit_FPS or Input_Reader.Fast_Forward;
         if Limit_FPS and not Input_Reader.Fast_Forward then
            Frame_Timer.Delay_Until_Next;
         end if;
      end loop;
   end Render_Loop;
begin
   if not SDL.Initialise then raise Program_Error; end if;

   Cli.Parse (Args);

   SDL.Log.Set (Category => SDL.Log.Application, Priority => Cli.Log_Priority (Args));

   Limit_FPS := not Cli.Uncapped_FPS (Args);

   Create (Window);
   Create (Audio_IO);
   Input.Create (Input_Reader);
   Create (Runner);

   Put_Debug ("Initializing libgade");
   Create (G);
   Put_Debug ("Setting up input handling");
   Set_Input_Reader (G, Input_Reader'Access);

   while not Input_Reader.Quit loop
      if Cli.ROM_Filename (Args) /= "" then
         Render_Loop (Cli.ROM_Filename (Args));
      elsif Input_Reader.File_Dropped then
         declare
            Filename : constant String := Input_Reader.Dropped_Filename;
         begin
            Input_Reader.Clear_Dropped_File;
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
end Main;
