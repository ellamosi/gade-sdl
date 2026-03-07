with SDL.Log; use SDL.Log;

package body Runtime.Logging is

   overriding
   procedure Log
     (Logger  : Instance;
      Level   : Gade.Logging.Log_Level;
      Message : String)
   is
      pragma Unreferenced (Logger);
   begin
      case Level is
         when Gade.Logging.Debug =>
            Put_Debug (Message);
         when Gade.Logging.Info =>
            Put_Info (Message);
         when Gade.Logging.Warn =>
            Put_Info (Message);
         when Gade.Logging.Error =>
            Put_Error (Message);
      end case;
   end Log;

end Runtime.Logging;
