with Ada.Directories;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.Traceback.Symbolic;

with Gade.Interfaces; use Gade.Interfaces;

with App_Menu;
with Audio.IO;                use Audio.IO;
with CLI;
with Input;
with Runtime;
with Runtime.Camera;
with Runtime.Frame_Pacing;
with Runtime.Logging;
with Runtime.Main_Loop;       use Runtime.Main_Loop;
with Video.Window;            use Video.Window;

with SDL.Error;
with SDL.Log; use SDL.Log;
with SDL.Message_Boxes;
with SDL.Timers;

procedure Main is
   use type SDL.Init_Flags;

   Required_SDL_Subsystems : constant SDL.Init_Flags :=
     SDL.Enable_Audio or SDL.Enable_Video or SDL.Enable_Events or SDL.Enable_Camera;

   G               : Gade_Type;
   Window          : aliased Window_Instance;
   Audio_IO        : Audio.IO.Instance;
   Input_Reader    : aliased Input.Instance;
   Camera_Provider : aliased Runtime.Camera.Instance;
   Gade_Logger     : aliased Runtime.Logging.Instance;
   Runner          : Runtime.Main_Loop.Instance;
   Menu            : App_Menu.Instance;
   Args            : CLI.Instance;
   Current_ROM     : Unbounded_String;
   SDL_Initialized : Boolean := False;
   G_Created       : Boolean := False;
   Run_Current_ROM : Boolean := False;
   Uncapped_FPS    : Boolean;

   procedure Display_FPS (Value : Float);
   procedure Display_FPS (Value : Float) is
   begin
      Window.Set_FPS (Value);
   end Display_FPS;

   package Window_FPS_Frame_Timers is new Runtime.Frame_Pacing (Display_FPS);

   Frame_Timer : Window_FPS_Frame_Timers.Frame_Timer;

   function Error_Message_Of (Occurence : Exception_Occurrence) return String;
   function Error_Message_Of (Occurence : Exception_Occurrence) return String is
      Message : constant String := Exception_Message (Occurence);
   begin
      if Message /= "" then
         return Message;
      end if;

      return Exception_Name (Occurence);
   end Error_Message_Of;

   procedure Set_Window_Title (ROM_Filename : String := "");
   procedure Set_Window_Title (ROM_Filename : String := "") is
   begin
      if ROM_Filename = "" then
         Window.Set_Title ("Gade");
      else
         Window.Set_Title
           ("Gade - " & Ada.Directories.Simple_Name (ROM_Filename));
      end if;
   end Set_Window_Title;

   procedure Show_Error (Title : String; Message : String);
   procedure Show_Error (Title : String; Message : String) is
   begin
      Ada.Text_IO.Put_Line (Title & ": " & Message);
      SDL.Message_Boxes.Show_Simple
        (Title   => Title,
        Message => Message,
         Flags   => SDL.Message_Boxes.Error_Box);
   exception
      when others =>
         null;
   end Show_Error;

   procedure Service_Input_Notifications;
   procedure Service_Input_Notifications is
   begin
      loop
         declare
            Message : constant String := Input_Reader.Consume_Error_Message;
         begin
            exit when Message = "";
            Show_Error ("Gade", Message);
         end;
      end loop;
   end Service_Input_Notifications;

   procedure Wait_Loop;
   procedure Wait_Loop is
   begin
      while not Input_Reader.Quit and not Input_Reader.File_Dropped loop
         Input_Reader.Poll;
         Service_Input_Notifications;

         exit when Input_Reader.Quit or Input_Reader.File_Dropped;
         SDL.Timers.Wait_Delay (Runtime.Ticks_Per_Frame);
      end loop;
   end Wait_Loop;

   procedure Render_Loop (ROM_Filename : String);
   procedure Render_Loop (ROM_Filename : String) is
      Was_Paused : Boolean := False;
   begin
      Put_Debug ("Loading ROM");
      Load_ROM (G, ROM_Filename);
      Reset (G);

      App_Menu.Set_ROM_Available (Menu, True, ROM_Filename);
      Set_Window_Title (ROM_Filename);
      Frame_Timer.Reset;

      while not Input_Reader.Quit
        and not Input_Reader.File_Dropped
        and not Input_Reader.Reset_Requested
      loop
         if Input_Reader.Paused then
            if not Was_Paused then
               Frame_Timer.Reset;
               Window.Set_FPS (0.0);
               Was_Paused := True;
            end if;

            Runtime.Camera.Service (Camera_Provider);
            Input_Reader.Poll;
            Service_Input_Notifications;

            exit when Input_Reader.Quit
              or else Input_Reader.File_Dropped
              or else Input_Reader.Reset_Requested;

            SDL.Timers.Wait_Delay (Runtime.Ticks_Per_Frame);
         else
            if Was_Paused then
               Frame_Timer.Reset;
               Was_Paused := False;
            end if;

            Frame_Timer.Time_Frame;

            Step (Runner, G, Window, Audio_IO);
            Runtime.Camera.Service (Camera_Provider);

            Input_Reader.Poll;
            Service_Input_Notifications;

            --  Re-apply frame cap if FF is triggered while it was on
            Uncapped_FPS := Uncapped_FPS and not Input_Reader.Fast_Forward;
            if not Uncapped_FPS and not Input_Reader.Fast_Forward then
               Frame_Timer.Delay_Until_Next;
            end if;
         end if;
      end loop;
   end Render_Loop;

   procedure Cleanup_Runtime;
   procedure Cleanup_Runtime is
   begin
      if G_Created then
         Finalize (G);
         G_Created := False;
      end if;

      if SDL_Initialized then
         Shutdown (Audio_IO);
         Runtime.Camera.Shutdown (Camera_Provider);
         App_Menu.Shutdown (Menu);
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
   App_Menu.Create (Menu, Window, Input_Reader);
   App_Menu.Set_ROM_Available (Menu, False);
   Window.Set_FPS (0.0);
   Set_Window_Title;

   Put_Debug ("Initializing gade");
   Create (G, Input_Reader'Access, Gade_Logger'Access, Camera_Provider'Access);
   G_Created := True;
   Put_Debug ("Input, camera and logging initialized");

   Current_ROM := To_Unbounded_String (CLI.ROM_Filename (Args));
   Run_Current_ROM := Current_ROM /= Null_Unbounded_String;

   while not Input_Reader.Quit loop
      if not Run_Current_ROM then
         Wait_Loop;
      end if;

      Service_Input_Notifications;
      exit when Input_Reader.Quit;

      if Input_Reader.File_Dropped then
         declare
            Filename : constant String := Input_Reader.Consume_Dropped_Filename;
         begin
            if Filename /= "" then
               Current_ROM := To_Unbounded_String (Filename);
               Run_Current_ROM := True;
            end if;
         end;
      elsif Input_Reader.Consume_Reset_Request then
         Run_Current_ROM := Current_ROM /= Null_Unbounded_String;
      end if;

      if Run_Current_ROM and then Current_ROM /= Null_Unbounded_String then
         declare
            ROM_Filename : constant String := To_String (Current_ROM);
         begin
            begin
               Render_Loop (ROM_Filename);
            exception
               when E : others =>
                  Current_ROM := Null_Unbounded_String;
                  Run_Current_ROM := False;
                  App_Menu.Set_ROM_Available (Menu, False);
                  Window.Set_FPS (0.0);
                  Set_Window_Title;
                  Show_Error
                    ("Unable to load ROM",
                     Error_Message_Of (E));
            end;

            exit when Input_Reader.Quit;

            if Input_Reader.File_Dropped then
               declare
                  Filename : constant String := Input_Reader.Consume_Dropped_Filename;
               begin
                  if Filename /= "" then
                     Current_ROM := To_Unbounded_String (Filename);
                     Run_Current_ROM := True;
                  else
                     Run_Current_ROM := False;
                  end if;
               end;
            elsif Input_Reader.Consume_Reset_Request then
               Run_Current_ROM := Current_ROM /= Null_Unbounded_String;
            else
               Run_Current_ROM := False;
            end if;
         end;
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
