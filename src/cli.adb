with GNAT.Command_Line; use GNAT.Command_Line;
with GNAT.Strings;

package body Cli is

   procedure Parse (Command_Line : out Instance) is
      Config           : Command_Line_Configuration;
      Uncapped_FPS     : aliased Boolean;
      Log_Priority_Str : aliased GNAT.Strings.String_Access;
   begin
      Set_Usage (Config, "[options] [rom_file]");
      Define_Switch
        (Config,
         Uncapped_FPS'Access,
         Switch => "-u",
         Long_Switch => "--uncapped",
         Help => "Uncap framerate indefinitely or until fast forwarding is " &
           "triggered",
         Value => True);
      Define_Switch
        (Config,
         Log_Priority_Str'Access,
         Switch => "-l=",
         Long_Switch => "--log=",
         Help => "Logging level. Example: --log=debug",
         Argument => "level");
      Define_Switch
        (Config,
         Switch => "-h",
         Long_Switch => "--help",
         Help => "Display help");
      Getopt (Config);

      Command_Line.Uncapped_FPS := Uncapped_FPS;
      Command_Line.Log_Priority := Parse_Log_Priority (Log_Priority_Str.all);
      Command_Line.ROM_Filename := To_Unbounded_String (Get_Argument);
      GNAT.Strings.Free (Log_Priority_Str);
   exception
      when others =>
         GNAT.Strings.Free (Log_Priority_Str);
         raise;
   end Parse;

   function Parse_Log_Priority (Priority : String) return SDL.Log.Priorities is
   begin
      if Priority = "" then
         return SDL.Log.Info;
      else
         return SDL.Log.Priorities'Value (Priority);
      end if;
   exception
      when Constraint_Error =>
         raise GNAT.Command_Line.Invalid_Parameter;
   end Parse_Log_Priority;

   function Uncapped_FPS (Command_Line : Instance) return Boolean is
   begin
      return Command_Line.Uncapped_FPS;
   end Uncapped_FPS;

   function Log_Priority (Command_Line : Instance) return SDL.Log.Priorities is
   begin
      return Command_Line.Log_Priority;
   end Log_Priority;

   function ROM_Filename (Command_Line : Instance) return String is
   begin
      return To_String (Command_Line.ROM_Filename);
   end ROM_Filename;

end Cli;
