with Ada.Directories;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Conversion;

with Interfaces.C;
with System;

with SDL.Dialogs;
with SDL.Events.Keyboards;

package body App_Menu is
   use type System.Address;
   use type SDL.Events.Keyboards.Key_Modifiers;

   type Window_Access is access all Video.Window.Window_Instance;
   type Input_Access is access all Input.Instance;

   type Callback_Context is record
      Window        : Window_Access := null;
      Input         : Input_Access := null;
      Last_ROM_Path : Unbounded_String := Null_Unbounded_String;
   end record;

   function To_Context is new Ada.Unchecked_Conversion
     (Source => System.Address,
      Target => Callback_Context_Access);

   function To_Address is new Ada.Unchecked_Conversion
     (Source => Callback_Context_Access,
      Target => System.Address);

   ROM_Filters : constant SDL.Dialogs.File_Filter_Lists :=
     [1 => (Name    => To_Unbounded_String ("Game Boy ROMs"),
            Pattern => To_Unbounded_String ("gb;gbc;sgb;bin")),
      2 => (Name    => To_Unbounded_String ("All Files"),
            Pattern => To_Unbounded_String ("*"))];

   function Error_Message_Of (Occurence : Exception_Occurrence) return String;
   function Default_Dialog_Location (Context : Callback_Context) return String;
   procedure Report_Error
     (Context : Callback_Context_Access;
      Message : String);
   procedure Open_ROM_Result
     (User_Data       : in System.Address;
      Status          : in SDL.Dialogs.Statuses;
      Files           : in SDL.Dialogs.File_Path_Lists;
      Selected_Filter : in Interfaces.C.int;
      Error_Message   : in String);
   procedure Open_ROM_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item);
   procedure Reset_ROM_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item);
   procedure Pause_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item);
   procedure Fullscreen_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item);
   procedure Quit_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item);

   function Error_Message_Of (Occurence : Exception_Occurrence) return String is
      Message : constant String := Exception_Message (Occurence);
   begin
      if Message /= "" then
         return Message;
      end if;

      return Exception_Name (Occurence);
   end Error_Message_Of;

   function Default_Dialog_Location (Context : Callback_Context) return String is
      Path : constant String := To_String (Context.Last_ROM_Path);
   begin
      if Path = "" then
         return "";
      end if;

      return Ada.Directories.Containing_Directory (Path);
   exception
      when others =>
         return "";
   end Default_Dialog_Location;

   procedure Report_Error
     (Context : Callback_Context_Access;
      Message : String) is
   begin
      if Context = null or else Context.Input = null then
         return;
      end if;

      Context.Input.all.Request_Error (Message);
   end Report_Error;

   procedure Open_ROM_Result
     (User_Data       : in System.Address;
      Status          : in SDL.Dialogs.Statuses;
      Files           : in SDL.Dialogs.File_Path_Lists;
      Selected_Filter : in Interfaces.C.int;
      Error_Message   : in String)
   is
      pragma Unreferenced (Selected_Filter);

      Context : constant Callback_Context_Access := To_Context (User_Data);
   begin
      if Context = null or else Context.Input = null then
         return;
      end if;

      case Status is
         when SDL.Dialogs.Accepted =>
            if Files'Length > 0 then
               Context.Input.all.Request_File (To_String (Files (Files'First)));
            end if;
         when SDL.Dialogs.Failed =>
            Report_Error
              (Context,
               "Unable to open ROM chooser: " &
               (if Error_Message /= "" then Error_Message else "unknown error"));
         when SDL.Dialogs.Cancelled =>
            null;
      end case;
   end Open_ROM_Result;

   procedure Open_ROM_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item)
   is
      pragma Unreferenced (Selected);

      Context : constant Callback_Context_Access := To_Context (User_Data);
   begin
      if Context = null or else Context.Window = null then
         return;
      end if;

      SDL.Dialogs.Show_Open_File_Dialog
        (Callback         => Open_ROM_Result'Access,
         Window           => Video.Window.Get_Handle (Context.Window.all).all,
         Filters          => ROM_Filters,
         Default_Location => Default_Dialog_Location (Context.all),
         Allow_Many       => False,
         User_Data        => User_Data);
   exception
      when E : others =>
         Report_Error
           (Context,
            "Unable to show ROM chooser: " & Error_Message_Of (E));
   end Open_ROM_Menu;

   procedure Reset_ROM_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item)
   is
      pragma Unreferenced (Selected);

      Context : constant Callback_Context_Access := To_Context (User_Data);
   begin
      if Context = null or else Context.Input = null then
         return;
      end if;

      Context.Input.all.Request_Reset;
   end Reset_ROM_Menu;

   procedure Pause_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item)
   is
      Context : constant Callback_Context_Access := To_Context (User_Data);
   begin
      if Context = null or else Context.Input = null then
         return;
      end if;

      Context.Input.all.Set_Paused (SDL.Menus.Get_Checked (Selected));
   end Pause_Menu;

   procedure Fullscreen_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item)
   is
      Context : constant Callback_Context_Access := To_Context (User_Data);
   begin
      if Context = null or else Context.Window = null then
         return;
      end if;

      Video.Window.Set_Fullscreen
        (Context.Window.all,
         SDL.Menus.Get_Checked (Selected));
      SDL.Menus.Set_Checked
        (Selected,
         Video.Window.Is_Fullscreen (Context.Window.all));
   exception
      when E : others =>
         if Context /= null and then Context.Window /= null then
            SDL.Menus.Set_Checked
              (Selected,
               Video.Window.Is_Fullscreen (Context.Window.all));
         end if;

         Report_Error
           (Context,
            "Unable to change fullscreen mode: " & Error_Message_Of (E));
   end Fullscreen_Menu;

   procedure Quit_Menu
     (User_Data : in System.Address;
      Selected  : in SDL.Menus.Menu_Item)
   is
      pragma Unreferenced (Selected);

      Context : constant Callback_Context_Access := To_Context (User_Data);
   begin
      if Context = null or else Context.Input = null then
         return;
      end if;

      Context.Input.all.Request_Quit;
   end Quit_Menu;

   procedure Create
     (Self   : in out Instance;
      Window : aliased in out Video.Window.Window_Instance;
      Input_State : aliased in out Input.Instance)
   is
      use type SDL.Menus.Menu_Item_Flags;

      Root            : SDL.Menus.Menu;
      File_Item       : SDL.Menus.Menu_Item;
      Emulation_Item  : SDL.Menus.Menu_Item;
      View_Item       : SDL.Menus.Menu_Item;
      File_Menu       : SDL.Menus.Menu;
      Emulation_Menu  : SDL.Menus.Menu;
      View_Menu       : SDL.Menus.Menu;
      Context_Address : System.Address;
   begin
      Self.Context :=
        new Callback_Context'
          (Window        => Window'Unchecked_Access,
           Input         => Input_State'Unchecked_Access,
           Last_ROM_Path => Null_Unbounded_String);

      SDL.Menus.Create
        (Self   => Self.Menu_Bar,
         Window => Video.Window.Get_Handle (Window).all);
      Root := SDL.Menus.Get_Root (Self.Menu_Bar);

      File_Item := SDL.Menus.Append (Root, "File", SDL.Menus.Submenu);
      Emulation_Item := SDL.Menus.Append (Root, "Emulation", SDL.Menus.Submenu);
      View_Item := SDL.Menus.Append (Root, "View", SDL.Menus.Submenu);

      File_Menu := SDL.Menus.Create_Submenu (File_Item);
      Emulation_Menu := SDL.Menus.Create_Submenu (Emulation_Item);
      View_Menu := SDL.Menus.Create_Submenu (View_Item);

      Context_Address := To_Address (Self.Context);

      Self.Open_Item := SDL.Menus.Append (File_Menu, "Open ROM...", SDL.Menus.Button);
      SDL.Menus.Set_Callback
        (Self.Open_Item,
         Open_ROM_Menu'Access,
         Context_Address);
      SDL.Menus.Set_Shortcut
        (Self.Open_Item,
         Key       => SDL.Events.Keyboards.Value ("O"),
         Modifiers => SDL.Events.Keyboards.Modifier_GUI);

      Self.Reset_Item :=
        SDL.Menus.Append
          (File_Menu,
           "Reset",
           SDL.Menus.Button or SDL.Menus.Disabled);
      SDL.Menus.Set_Callback
        (Self.Reset_Item,
         Reset_ROM_Menu'Access,
         Context_Address);
      SDL.Menus.Set_Shortcut
        (Self.Reset_Item,
         Key       => SDL.Events.Keyboards.Value ("R"),
         Modifiers => SDL.Events.Keyboards.Modifier_GUI);

      declare
         Separator : constant SDL.Menus.Menu_Item :=
           SDL.Menus.Insert_Separator_At (File_Menu);
         pragma Unreferenced (Separator);
      begin
         null;
      end;

      Self.Quit_Item := SDL.Menus.Append (File_Menu, "Quit", SDL.Menus.Button);
      SDL.Menus.Set_Callback
        (Self.Quit_Item,
         Quit_Menu'Access,
         Context_Address);
      SDL.Menus.Set_Shortcut
        (Self.Quit_Item,
         Key       => SDL.Events.Keyboards.Value ("Q"),
         Modifiers => SDL.Events.Keyboards.Modifier_GUI);

      Self.Pause_Item :=
        SDL.Menus.Append
          (Emulation_Menu,
           "Pause",
           SDL.Menus.Checkbox or SDL.Menus.Disabled);
      SDL.Menus.Set_Callback
        (Self.Pause_Item,
         Pause_Menu'Access,
         Context_Address);
      SDL.Menus.Set_Shortcut
        (Self.Pause_Item,
         Key       => SDL.Events.Keyboards.Value ("P"),
         Modifiers => SDL.Events.Keyboards.Modifier_GUI);

      Self.Fullscreen_Item :=
        SDL.Menus.Append
          (View_Menu,
           "Fullscreen",
           SDL.Menus.Checkbox);
      SDL.Menus.Set_Callback
        (Self.Fullscreen_Item,
         Fullscreen_Menu'Access,
         Context_Address);
      SDL.Menus.Set_Checked
        (Self.Fullscreen_Item,
         Video.Window.Is_Fullscreen (Window));
      SDL.Menus.Set_Shortcut
        (Self.Fullscreen_Item,
         Key       => SDL.Events.Keyboards.Value ("F"),
         Modifiers =>
           SDL.Events.Keyboards.Modifier_GUI or
           SDL.Events.Keyboards.Modifier_Control);

      Self.Is_Created := True;
   exception
      when others =>
         Shutdown (Self);
         raise;
   end Create;

   procedure Shutdown (Self : in out Instance) is
   begin
      if Self.Is_Created then
         SDL.Menus.Finalize (Self.Menu_Bar);
         Self.Is_Created := False;
      end if;
   end Shutdown;

   procedure Set_ROM_Available
     (Self      : in out Instance;
      Available : Boolean;
      Path      : String := "") is
   begin
      if Self.Context /= null and then Path /= "" then
         Self.Context.Last_ROM_Path := To_Unbounded_String (Path);
      end if;

      if not Self.Is_Created then
         return;
      end if;

      SDL.Menus.Set_Enabled (Self.Reset_Item, Available);
      SDL.Menus.Set_Enabled (Self.Pause_Item, Available);

      if Available then
         if Self.Context /= null and then Self.Context.Input /= null then
            SDL.Menus.Set_Checked
              (Self.Pause_Item,
               Input.Paused (Self.Context.Input.all));
         end if;
      else
         if Self.Context /= null and then Self.Context.Input /= null then
            Self.Context.Input.all.Set_Paused (False);
         end if;

         SDL.Menus.Set_Checked (Self.Pause_Item, False);
      end if;

      if Self.Context /= null and then Self.Context.Window /= null then
         SDL.Menus.Set_Checked
           (Self.Fullscreen_Item,
            Video.Window.Is_Fullscreen (Self.Context.Window.all));
      end if;
   end Set_ROM_Available;

   overriding
   procedure Finalize (Self : in out Instance) is
   begin
      Shutdown (Self);
   end Finalize;

end App_Menu;
