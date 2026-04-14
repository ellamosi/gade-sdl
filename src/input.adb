with SDL.Events.Files;
with SDL.Events.Keyboards;
with SDL.Log;

with Interfaces.C.Strings; use Interfaces.C.Strings;

package body Input is

   procedure Create (Input : out Instance) is
   begin
      if Input.Shared = null then
         Input.Shared := new Shared_State;
      end if;

      Input.Shared.Initialize;
   end Create;

   overriding
   function Read_Input (Input : Instance) return State is
   begin
      if Input.Shared = null then
         return (others => False);
      end if;

      return Input.Shared.Read_Buttons;
   end Read_Input;

   procedure Poll (Input : in out Instance) is
      Event : SDL.Events.Events.Events;
   begin
      while SDL.Events.Events.Poll (Event) loop
         Set_Event (Input, Event);
      end loop;
   end Poll;

   procedure Wait (Input : in out Instance) is
      Event : SDL.Events.Events.Events;
   begin
      SDL.Events.Events.Wait (Event);
      Set_Event (Input, Event);
   exception
      --  Some OSs (MacOS) might arbitrarily trigger event exceptions
      when SDL.Events.Events.Event_Error =>
         SDL.Log.Put_Debug ("Event Error");
   end Wait;

   procedure Set_Event
     (Input : in out Instance;
      Event : in out SDL.Events.Events.Events)
   is
   begin
      case Event.Common.Event_Type is
         when SDL.Events.Keyboards.Key_Down =>
            Input.Set_Button_Pressed (Event, True);
         when SDL.Events.Keyboards.Key_Up =>
            Input.Set_Button_Pressed (Event, False);
         when SDL.Events.Files.Drop_File =>
            SDL.Log.Put_Debug ("File dropped");
            Input.Request_File (Value (Event.Drop.File_Name));
         when SDL.Events.Quit =>
            Input.Request_Quit;
         when others =>
            null;
      end case;
   end Set_Event;

   function Quit (Input : Instance) return Boolean is
   begin
      if Input.Shared = null then
         return False;
      end if;

      return Input.Shared.Quit;
   end Quit;

   procedure Request_Quit (Input : in out Instance) is
   begin
      pragma Assert (Input.Shared /= null);
      Input.Shared.Request_Quit;
   end Request_Quit;

   function Fast_Forward (Input : Instance) return Boolean is
   begin
      if Input.Shared = null then
         return False;
      end if;

      return Input.Shared.Fast_Forward;
   end Fast_Forward;

   function Paused (Input : Instance) return Boolean is
   begin
      if Input.Shared = null then
         return False;
      end if;

      return Input.Shared.Paused;
   end Paused;

   procedure Set_Paused
     (Input : in out Instance;
      Value : Boolean) is
   begin
      pragma Assert (Input.Shared /= null);
      Input.Shared.Set_Paused (Value);
   end Set_Paused;

   function File_Dropped (Input : Instance) return Boolean is
   begin
      if Input.Shared = null then
         return False;
      end if;

      return Input.Shared.File_Dropped;
   end File_Dropped;

   procedure Request_File
     (Input    : in out Instance;
      Filename : String) is
   begin
      pragma Assert (Input.Shared /= null);
      Input.Shared.Request_File (Filename);
   end Request_File;

   function Consume_Dropped_Filename (Input : in out Instance) return String is
      Filename : Unbounded_String;
   begin
      pragma Assert (Input.Shared /= null);
      Input.Shared.Consume_File (Filename);
      return To_String (Filename);
   end Consume_Dropped_Filename;

   function Reset_Requested (Input : Instance) return Boolean is
   begin
      if Input.Shared = null then
         return False;
      end if;

      return Input.Shared.Reset_Requested;
   end Reset_Requested;

   procedure Request_Reset (Input : in out Instance) is
   begin
      pragma Assert (Input.Shared /= null);
      Input.Shared.Request_Reset;
   end Request_Reset;

   function Consume_Reset_Request (Input : in out Instance) return Boolean is
      Requested : Boolean;
   begin
      pragma Assert (Input.Shared /= null);
      Input.Shared.Consume_Reset_Request (Requested);
      return Requested;
   end Consume_Reset_Request;

   function Has_Error (Input : Instance) return Boolean is
   begin
      if Input.Shared = null then
         return False;
      end if;

      return Input.Shared.Has_Error;
   end Has_Error;

   procedure Request_Error
     (Input   : in out Instance;
      Message : String) is
   begin
      pragma Assert (Input.Shared /= null);
      Input.Shared.Request_Error (Message);
   end Request_Error;

   function Consume_Error_Message (Input : in out Instance) return String is
      Message : Unbounded_String;
   begin
      pragma Assert (Input.Shared /= null);
      Input.Shared.Consume_Error (Message);
      return To_String (Message);
   end Consume_Error_Message;

   procedure Set_Button_Pressed
     (Input   : in out Instance;
      Event   : SDL.Events.Events.Events;
      Pressed : Boolean)
   is
   begin
      case Event.Keyboard.Key_Sym.Scan_Code is
         when SDL.Events.Keyboards.Scan_Code_Z =>
            Input.Shared.Set_Button (A_Button, Pressed);
         when SDL.Events.Keyboards.Scan_Code_X =>
            Input.Shared.Set_Button (B_Button, Pressed);
         when SDL.Events.Keyboards.Scan_Code_Left =>
            Input.Shared.Set_Button (Left_Button, Pressed);
         when SDL.Events.Keyboards.Scan_Code_Right =>
            Input.Shared.Set_Button (Right_Button, Pressed);
         when SDL.Events.Keyboards.Scan_Code_Up =>
            Input.Shared.Set_Button (Up_Button, Pressed);
         when SDL.Events.Keyboards.Scan_Code_Down =>
            Input.Shared.Set_Button (Down_Button, Pressed);
         when SDL.Events.Keyboards.Scan_Code_Return =>
            Input.Shared.Set_Button (Start_Button, Pressed);
         when SDL.Events.Keyboards.Scan_Code_Backspace =>
            Input.Shared.Set_Button (Select_Button, Pressed);
         when SDL.Events.Keyboards.Scan_Code_Space =>
            Input.Shared.Set_Fast_Forward (Pressed);
         when others => null;
      end case;
   end Set_Button_Pressed;

   protected body Shared_State is
      procedure Initialize is
      begin
         Buttons := (others => False);
         Quit_Requested := False;
         Fast_Forward_Enabled := False;
         Paused_State := False;
         Reset_Requested_Flag := False;
         Pending_File := Null_Unbounded_String;
         Pending_Error := Null_Unbounded_String;
      end Initialize;

      function Read_Buttons return State is
      begin
         return Buttons;
      end Read_Buttons;

      procedure Set_Button
        (Button  : Button_Kinds;
         Pressed : Boolean) is
      begin
         case Button is
            when A_Button =>
               Buttons.A := Pressed;
            when B_Button =>
               Buttons.B := Pressed;
            when Left_Button =>
               Buttons.LEFT := Pressed;
            when Right_Button =>
               Buttons.RIGHT := Pressed;
            when Up_Button =>
               Buttons.UP := Pressed;
            when Down_Button =>
               Buttons.DOWN := Pressed;
            when Start_Button =>
               Buttons.START := Pressed;
            when Select_Button =>
               Buttons.SEL := Pressed;
         end case;
      end Set_Button;

      procedure Set_Fast_Forward (Pressed : Boolean) is
      begin
         Fast_Forward_Enabled := Pressed;
      end Set_Fast_Forward;

      function Fast_Forward return Boolean is
      begin
         return Fast_Forward_Enabled;
      end Fast_Forward;

      procedure Request_Quit is
      begin
         Quit_Requested := True;
      end Request_Quit;

      function Quit return Boolean is
      begin
         return Quit_Requested;
      end Quit;

      procedure Set_Paused (Value : Boolean) is
      begin
         Paused_State := Value;
      end Set_Paused;

      function Paused return Boolean is
      begin
         return Paused_State;
      end Paused;

      procedure Request_File (Filename : String) is
      begin
         Pending_File := To_Unbounded_String (Filename);
      end Request_File;

      function File_Dropped return Boolean is
      begin
         return Pending_File /= Null_Unbounded_String;
      end File_Dropped;

      procedure Consume_File (Filename : out Unbounded_String) is
      begin
         Filename := Pending_File;
         Pending_File := Null_Unbounded_String;
      end Consume_File;

      procedure Request_Reset is
      begin
         Reset_Requested_Flag := True;
      end Request_Reset;

      function Reset_Requested return Boolean is
      begin
         return Reset_Requested_Flag;
      end Reset_Requested;

      procedure Consume_Reset_Request (Requested : out Boolean) is
      begin
         Requested := Reset_Requested_Flag;
         Reset_Requested_Flag := False;
      end Consume_Reset_Request;

      procedure Request_Error (Message : String) is
      begin
         Pending_Error := To_Unbounded_String (Message);
      end Request_Error;

      function Has_Error return Boolean is
      begin
         return Pending_Error /= Null_Unbounded_String;
      end Has_Error;

      procedure Consume_Error (Message : out Unbounded_String) is
      begin
         Message := Pending_Error;
         Pending_Error := Null_Unbounded_String;
      end Consume_Error;
   end Shared_State;

end Input;
