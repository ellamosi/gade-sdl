with Ada.Finalization;

with Input;
with SDL.Menus;
with Video.Window;

package App_Menu is

   type Instance is new Ada.Finalization.Limited_Controlled with private;

   procedure Create
     (Self   : in out Instance;
      Window : aliased in out Video.Window.Window_Instance;
      Input_State : aliased in out Input.Instance);

   procedure Shutdown (Self : in out Instance);

   procedure Set_ROM_Available
     (Self      : in out Instance;
      Available : Boolean;
      Path      : String := "");

   overriding
   procedure Finalize (Self : in out Instance);

private
   type Callback_Context;
   type Callback_Context_Access is access all Callback_Context;

   type Instance is new Ada.Finalization.Limited_Controlled with record
      Menu_Bar        : SDL.Menus.Menu_Bar;
      Open_Item       : SDL.Menus.Menu_Item := SDL.Menus.Null_Item;
      Reset_Item      : SDL.Menus.Menu_Item := SDL.Menus.Null_Item;
      Pause_Item      : SDL.Menus.Menu_Item := SDL.Menus.Null_Item;
      Fullscreen_Item : SDL.Menus.Menu_Item := SDL.Menus.Null_Item;
      Quit_Item       : SDL.Menus.Menu_Item := SDL.Menus.Null_Item;
      Context         : Callback_Context_Access := null;
      Is_Created      : Boolean := False;
   end record;

end App_Menu;
