with Ada.Text_IO;

with GNAT.Traceback.Symbolic;

with Gade.Interfaces; use Gade.Interfaces;

with Audio.IO;            use Audio.IO;
with Runtime.Main_Loop;        use Runtime.Main_Loop;
with Runtime.Camera;
with Runtime.Logging;
with Video.Window;        use Video.Window;
with Input;
with CLI;
with Runtime.Frame_Pacing;

with SDL.Log; use SDL.Log;
with SDL.Error;

with Ada.Exceptions; use Ada.Exceptions;

procedure Main is
   use type SDL.Init_Flags;

   Required_SDL_Subsystems : constant SDL.Init_Flags :=
     SDL.Enable_Audio or SDL.Enable_Video or SDL.Enable_Events or SDL.Enable_Camera;

   G               : Gade_Type;
   Window          : Window_Instance;
   Audio_IO        : Audio.IO.Instance;
   Input_Reader    : aliased Input.Instance;
   Camera_Provider : aliased Runtime.Camera.Instance;
   Gade_Logger     : aliased Runtime.Logging.Instance;
   Runner          : Runtime.Main_Loop.Instance;
   Args            : CLI.Instance;
   SDL_Initialized : Boolean := False;
   Uncapped_FPS    : Boolean;

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

         --  Re-apply frame cap if FF is triggered while it was on
         Uncapped_FPS := Uncapped_FPS and not Input_Reader.Fast_Forward;
         if not Uncapped_FPS and not Input_Reader.Fast_Forward then
            Frame_Timer.Delay_Until_Next;
         end if;
      end loop;
   end Render_Loop;

   procedure Cleanup_Runtime;
   procedure Cleanup_Runtime is
   begin
      if SDL_Initialized then
         --  Local resources are controlled and will get automatically finalized
         Shutdown (Audio_IO);
         Runtime.Camera.Shutdown (Camera_Provider);
         Shutdown (Window);
         SDL.Finalise;
         SDL_Initialized := False;
      end if;
   end Cleanup_Runtime;
begin
   if not SDL.Initialise (Required_SDL_Subsystems) then
      Ada.Text_IO.Put_Line ("SDL initialization failed: " & SDL.Error.Get);
      return;
   end if;
   SDL_Initialized := True;

   CLI.Parse (Args);

   SDL.Log.Set (Category => SDL.Log.Application, Priority => CLI.Log_Priority (Args));

   Uncapped_FPS := CLI.Uncapped_FPS (Args);

   Create (Window);
   Create (Audio_IO);
   Input.Create (Input_Reader);
   Runtime.Camera.Create (Camera_Provider);
   Create (Runner);

   Put_Debug ("Initializing gade");
   Create (G, Input_Reader'Access, Gade_Logger'Access, Camera_Provider'Access);
   Put_Debug ("Input, camera and logging initialized");

   while not Input_Reader.Quit loop
      if Input_Reader.File_Dropped then
         declare
            Filename : constant String := Input_Reader.Dropped_Filename;
         begin
            Input_Reader.Clear_Dropped_File;
            Render_Loop (Filename);
         end;
      elsif CLI.ROM_Filename (Args) /= "" then
         Render_Loop (CLI.ROM_Filename (Args));
      else
         Wait_Loop;
      end if;
   end loop;

   Cleanup_Runtime;
exception
   when E : others =>
      Cleanup_Runtime;
      Ada.Text_IO.Put_Line ("Main Thread Exception");
      Ada.Text_IO.Put_Line (Exception_Message (E));
      Ada.Text_IO.Put_Line (GNAT.Traceback.Symbolic.Symbolic_Traceback (E));
end Main;
