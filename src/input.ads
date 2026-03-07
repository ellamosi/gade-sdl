with Gade.Input; use Gade.Input;

with SDL.Events.Events;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Input is

   type Instance is new Reader_Interface with private;

   procedure Create (Input : out Instance);

   overriding
   function Read_Input (Input : Instance) return State;

   procedure Poll (Input : in out Instance);

   procedure Wait (Input : in out Instance);

   function Quit (Input : Instance) return Boolean;

   function Fast_Forward (Input : Instance) return Boolean;

   function File_Dropped (Input : Instance) return Boolean;

   function Dropped_Filename (Input : Instance) return String;

   procedure Clear_Dropped_File (Input : in out Instance);

private

   type Instance is new Reader_Interface with record
      Buttons      : State;
      Quit         : Boolean;
      Fast_Forward : Boolean;
      File         : Unbounded_String;
   end record;

   procedure Set_Event
     (Input   : in out Instance;
      Event   : in out SDL.Events.Events.Events);

   procedure Set_Button_Pressed
     (Input   : in out Instance;
      Event   : SDL.Events.Events.Events;
      Pressed : Boolean);

end Input;
