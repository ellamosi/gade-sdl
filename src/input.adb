with SDL.Events.Files;
with SDL.Events.Keyboards;
with SDL.Log;

with Interfaces.C.Strings; use Interfaces.C.Strings;

package body Input is

   procedure Create (Input : out Instance) is
   begin
      Input.Buttons := (others => False);
      Input.Quit := False;
      Input.Fast_Forward := False;
      Input.File := Null_Unbounded_String;
   end Create;

   overriding
   function Read_Input (Input : Instance) return Input_State is
   begin
      return Input.Buttons;
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
            Input.File := To_Unbounded_String (Value (Event.Drop.File_Name));
            Free (Event.Drop.File_Name);
         when SDL.Events.Quit =>
            Input.Quit := True;
         when others =>
            null;
      end case;
   end Set_Event;

   function Quit (Input : Instance) return Boolean is
   begin
      return Input.Quit;
   end Quit;

   function Fast_Forward (Input : Instance) return Boolean is
   begin
      return Input.Fast_Forward;
   end Fast_Forward;

   function File_Dropped (Input : Instance) return Boolean is
   begin
      return Input.File /= Null_Unbounded_String;
   end File_Dropped;

   function Dropped_Filename (Input : Instance) return String is
   begin
      return To_String (Input.File);
   end Dropped_Filename;

   procedure Clear_Dropped_File (Input : in out Instance) is
   begin
      Input.File := Null_Unbounded_String;
   end Clear_Dropped_File;

   procedure Set_Button_Pressed
     (Input   : in out Instance;
      Event   : SDL.Events.Events.Events;
      Pressed : Boolean)
   is
      Buttons : Input_State renames Input.Buttons;
   begin
      case Event.Keyboard.Key_Sym.Scan_Code is
         when SDL.Events.Keyboards.Scan_Code_Z =>
            Buttons.A := Pressed;
         when SDL.Events.Keyboards.Scan_Code_X =>
            Buttons.B := Pressed;
         when SDL.Events.Keyboards.Scan_Code_Left =>
            Buttons.LEFT := Pressed;
         when SDL.Events.Keyboards.Scan_Code_Right =>
            Buttons.RIGHT := Pressed;
         when SDL.Events.Keyboards.Scan_Code_Up =>
            Buttons.UP := Pressed;
         when SDL.Events.Keyboards.Scan_Code_Down =>
            Buttons.DOWN := Pressed;
         when SDL.Events.Keyboards.Scan_Code_Return =>
            Buttons.START := Pressed;
         when SDL.Events.Keyboards.Scan_Code_Backspace =>
            Buttons.SEL := Pressed;
         when SDL.Events.Keyboards.Scan_Code_Space =>
            Input.Fast_Forward := Pressed;
         when others => null;
      end case;
   end Set_Button_Pressed;

end Input;
