with Ada.Finalization; use Ada.Finalization;

with Gade.Video_Buffer; use Gade.Video_Buffer;

with SDL.Video.Windows;
with SDL.Video.Textures;
with SDL.Video.Renderers;

package Video.Window is

   type Window_Instance is new Limited_Controlled with private;

   procedure Create (Window : out Window_Instance);

   procedure Shutdown (Window : in out Window_Instance);

   generic
      with procedure Generate_Frame (Buffer : RGB32_Display_Buffer_Access);
   procedure Render_Frame (Window : in out Window_Instance);

   procedure Set_FPS
     (Window : in out Window_Instance;
      FPS    : Float)
      with Pre => FPS >= 0.0 or else raise Constraint_Error;

   overriding
   procedure Finalize (Window : in out Window_Instance);

private

   type Window_Instance is new Limited_Controlled with record
      Window   : SDL.Video.Windows.Window;
      Texture  : SDL.Video.Textures.Texture;
      Renderer : SDL.Video.Renderers.Renderer;
      Is_Created  : Boolean := False;
      Is_Shutdown : Boolean := False;
   end record;

end Video.Window;
