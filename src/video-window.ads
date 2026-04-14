with Ada.Finalization; use Ada.Finalization;

with Gade.Video_Buffer; use Gade.Video_Buffer;

with SDL.GPU;
with SDL.Video.Windows;

package Video.Window is

   type Window_Instance is new Limited_Controlled with private;

   procedure Create (Window : out Window_Instance);

   procedure Shutdown (Window : in out Window_Instance);

   function Get_Handle
     (Window : aliased in out Window_Instance)
      return not null access SDL.Video.Windows.Window;

   procedure Set_Title
     (Window : in out Window_Instance;
      Title  : String);

   procedure Set_Fullscreen
     (Window  : in out Window_Instance;
      Enabled : Boolean);

   function Is_Fullscreen (Window : Window_Instance) return Boolean;

   generic
      with procedure Generate_Frame (Buffer : RGB32_Display_Buffer_Access);
   procedure Render_Frame (Window : in out Window_Instance);

   procedure Set_FPS
     (Window : in out Window_Instance;
      FPS    : Float)
      with Pre => FPS >= 0.0;

   overriding
   procedure Finalize (Window : in out Window_Instance);

private

   type Window_Instance is new Limited_Controlled with record
      Window            : aliased SDL.Video.Windows.Window;
      Device            : SDL.GPU.Device;
      Upload_Buffer     : SDL.GPU.Transfer_Buffer;
      Source_Texture    : SDL.GPU.Texture;
      Sampler           : SDL.GPU.Sampler;
      Vertex_Shader     : SDL.GPU.Shader;
      Fragment_Shader   : SDL.GPU.Shader;
      Pipeline          : SDL.GPU.Graphics_Pipeline;
      Is_Window_Claimed : Boolean := False;
      Is_Created        : Boolean := False;
      Is_Shutdown       : Boolean := False;
   end record;

end Video.Window;
