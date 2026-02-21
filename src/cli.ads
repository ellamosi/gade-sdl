with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with SDL.Log;

package CLI is

   type Instance is tagged private;

   procedure Parse (Command_Line : out Instance);

   function Uncapped_FPS (Command_Line : Instance) return Boolean;

   function Log_Priority (Command_Line : Instance) return SDL.Log.Priorities;

   function ROM_Filename (Command_Line : Instance) return String;

private

   type Instance is tagged record
      Uncapped_FPS : Boolean;
      Log_Priority : SDL.Log.Priorities;
      ROM_Filename : Unbounded_String;
   end record;

   function Parse_Log_Priority (Priority : String) return SDL.Log.Priorities;

end CLI;
