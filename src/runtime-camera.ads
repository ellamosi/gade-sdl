with Ada.Real_Time;
with Gade.Camera;
with SDL.Cameras;

package Runtime.Camera is

   type Instance is new Gade.Camera.Provider_Interface with private;

   procedure Create (Provider : in out Instance);

   procedure Shutdown (Provider : in out Instance);

   procedure Service (Provider : in out Instance);

   overriding
   procedure Set_Capture_Active
     (Provider : in out Instance;
      Active   : Boolean);

   overriding
   procedure Capture_Frame
     (Provider : Instance;
      Frame    : out Gade.Camera.Bitmap);

private

   type State;
   type State_Access is access all State;

   type Instance is new Gade.Camera.Provider_Interface with record
      State : State_Access := null;
   end record;

   type State is limited record
      Device                 : SDL.Cameras.Camera;
      Capture_Active         : Boolean := False;
      Close_Deadline_Valid   : Boolean := False;
      Last_Frame             : Gade.Camera.Bitmap := [others => [others => 0]];
      Have_Last_Frame        : Boolean := False;
      Capture_Error_Seen     : Boolean := False;
      Permission_State_Seen  : Boolean := False;
      Last_Permission_State  : SDL.Cameras.Permission_States := SDL.Cameras.Pending;
      Seen_Real_Frame        : Boolean := False;
      Close_Deadline         : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;

end Runtime.Camera;
