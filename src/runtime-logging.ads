with Gade.Logging;

package Runtime.Logging is

   type Instance is new Gade.Logging.Logger_Interface with private;

   overriding
   procedure Log
     (Logger  : Instance;
      Level   : Gade.Logging.Log_Level;
      Message : String);

private

   type Instance is new Gade.Logging.Logger_Interface with null record;

end Runtime.Logging;
