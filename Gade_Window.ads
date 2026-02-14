with Ada.Finalization; use Ada.Finalization;

with Gade.Video_Buffer; use Gade.Video_Buffer;

with SDL.Video.Windows;
with SDL.Video.Textures;
with SDL.Video.Renderers;

package Gade_Window is

   type Gade_Window_Type is new Limited_Controlled with private;

   procedure Create (Window : out Gade_Window_Type);

   procedure Shutdown (Window : in out Gade_Window_Type);

   generic
      with procedure Generate_Frame (Buffer : RGB32_Display_Buffer_Access);
   procedure Render_Frame (Window : in out Gade_Window_Type);

   procedure Set_FPS
     (Window : in out Gade_Window_Type;
      FPS    : Float);

   overriding
   procedure Finalize (Window : in out Gade_Window_Type);

private

   type Gade_Window_Type is new Limited_Controlled with record
      Window   : SDL.Video.Windows.Window;
      Texture  : SDL.Video.Textures.Texture;
      Renderer : SDL.Video.Renderers.Renderer;
      Is_Created  : Boolean := False;
      Is_Shutdown : Boolean := False;
   end record;

end Gade_Window;
