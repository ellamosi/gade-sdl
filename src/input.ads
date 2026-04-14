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

   procedure Request_Quit (Input : in out Instance);

   function Fast_Forward (Input : Instance) return Boolean;

   function Paused (Input : Instance) return Boolean;

   procedure Set_Paused
     (Input : in out Instance;
      Value : Boolean);

   function File_Dropped (Input : Instance) return Boolean;

   procedure Request_File
     (Input    : in out Instance;
      Filename : String);

   function Consume_Dropped_Filename (Input : in out Instance) return String;

   function Reset_Requested (Input : Instance) return Boolean;

   procedure Request_Reset (Input : in out Instance);

   function Consume_Reset_Request (Input : in out Instance) return Boolean;

   function Has_Error (Input : Instance) return Boolean;

   procedure Request_Error
     (Input   : in out Instance;
      Message : String);

   function Consume_Error_Message (Input : in out Instance) return String;

private
   type Button_Kinds is
     (A_Button,
      B_Button,
      Left_Button,
      Right_Button,
      Up_Button,
      Down_Button,
      Start_Button,
      Select_Button);

   protected type Shared_State is
      procedure Initialize;

      function Read_Buttons return State;

      procedure Set_Button
        (Button  : Button_Kinds;
         Pressed : Boolean);

      procedure Set_Fast_Forward (Pressed : Boolean);

      function Fast_Forward return Boolean;

      procedure Request_Quit;

      function Quit return Boolean;

      procedure Set_Paused (Value : Boolean);

      function Paused return Boolean;

      procedure Request_File (Filename : String);

      function File_Dropped return Boolean;

      procedure Consume_File (Filename : out Unbounded_String);

      procedure Request_Reset;

      function Reset_Requested return Boolean;

      procedure Consume_Reset_Request (Requested : out Boolean);

      procedure Request_Error (Message : String);

      function Has_Error return Boolean;

      procedure Consume_Error (Message : out Unbounded_String);

   private
      Buttons              : State := (others => False);
      Quit_Requested       : Boolean := False;
      Fast_Forward_Enabled : Boolean := False;
      Paused_State         : Boolean := False;
      Reset_Requested_Flag : Boolean := False;
      Pending_File         : Unbounded_String := Null_Unbounded_String;
      Pending_Error        : Unbounded_String := Null_Unbounded_String;
   end Shared_State;

   type Shared_State_Access is access all Shared_State;

   type Instance is new Reader_Interface with record
      Shared : Shared_State_Access := null;
   end record;

   procedure Set_Event
     (Input   : in out Instance;
      Event   : in out SDL.Events.Events.Events);

   procedure Set_Button_Pressed
     (Input   : in out Instance;
      Event   : SDL.Events.Events.Events;
      Pressed : Boolean);

end Input;
