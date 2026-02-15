with Gade.Input_Reader; use Gade.Input_Reader;

with SDL.Events.Events;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Input is

   type Instance is new Input_Reader_Type with private;

   procedure Create (Input : out Instance);

   overriding
   function Read_Input (Input : Instance) return Input_State;

   procedure Poll (Input : in out Instance);

   procedure Wait (Input : in out Instance);

   function Quit (Input : Instance) return Boolean;

   function Fast_Forward (Input : Instance) return Boolean;

   function File_Dropped (Input : Instance) return Boolean;

   function Dropped_Filename (Input : Instance) return String;

   procedure Clear_Dropped_File (Input : in out Instance);

private

   type Instance is new Input_Reader_Type with record
      Buttons      : Input_State;
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
