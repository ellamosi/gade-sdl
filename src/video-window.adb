with Ada.Unchecked_Conversion;

with Interfaces.C; use Interfaces.C;

with SDL.Video.Windows.Makers;
with SDL.Video.Renderers.Makers;
with SDL.Video.Textures.Makers;
with SDL.Video.Pixel_Formats;
with SDL.Video.Pixels;
with SDL.Log; use SDL.Log;
package body Video.Window is
   Cocoa_Renderer_Driver : constant Positive := 1;
   --  Preferred renderer driver on macOS for sharper scaling in this setup.

   procedure Create (Window : out Window_Instance) is
      Window_Created   : Boolean := False;
      Renderer_Created : Boolean := False;
      Texture_Created  : Boolean := False;

      procedure Create_Default_Renderer;
      procedure Create_Default_Renderer is
      begin
         SDL.Video.Renderers.Makers.Create
           (Rend   => Window.Renderer,
            Window => Window.Window,
            Flags  => SDL.Video.Renderers.Accelerated);
      end Create_Default_Renderer;
   begin
      SDL.Video.Windows.Makers.Create
        (Win    => Window.Window,
         Title  => "Gade",
         X      => 100,
         Y      => 100,
         Width  => Display_Width * 2,
         Height => Display_Height * 2);
      Window_Created := True;

      begin
         SDL.Video.Renderers.Makers.Create
           (Rend   => Window.Renderer,
            Window => Window.Window,
            Driver => Cocoa_Renderer_Driver,
            --  Cocoa: preferred on macOS as it avoids blurry scaling.
            Flags  => SDL.Video.Renderers.Accelerated);

         --  Validate renderer creation; Maker.Create does not raise on failure.
         SDL.Video.Renderers.Clear (Window.Renderer);
         Renderer_Created := True;
      exception
         when SDL.Video.Renderers.Renderer_Error =>
            SDL.Video.Renderers.Finalize (Window.Renderer);
            Create_Default_Renderer;
            Renderer_Created := True;
            SDL.Video.Renderers.Clear (Window.Renderer);
      end;

      SDL.Video.Textures.Makers.Create
        (Tex      => Window.Texture,
         Renderer => Window.Renderer,
         Format   => SDL.Video.Pixel_Formats.Pixel_Format_RGB_888,
         Kind     => SDL.Video.Textures.Streaming,
         Size     => (Display_Width, Display_Height));
      Texture_Created := True;
      Window.Is_Created := True;
      Window.Is_Shutdown := False;
   exception
      when others =>
         if Texture_Created then
            SDL.Video.Textures.Finalize (Window.Texture);
         end if;

         if Renderer_Created then
            SDL.Video.Renderers.Finalize (Window.Renderer);
         end if;

         if Window_Created then
            SDL.Video.Windows.Finalize (Window.Window);
         end if;

         Window.Is_Created := False;
         Window.Is_Shutdown := False;
         raise;
   end Create;

   procedure SDL_Texture_Lock is
     new SDL.Video.Textures.Lock
       (Pixel_Pointer_Type => SDL.Video.Pixels.ARGB_8888_Access.Pointer);

   --  The locked SDL texture memory is intentionally reinterpreted as the
   --  emulator display buffer type within the lock/unlock scope.
   type RGB32_Display_Buffer_Access is access all RGB32_Display_Buffer;
   pragma No_Strict_Aliasing (RGB32_Display_Buffer_Access);

   function ARGB_8888_Pointer_To_RGB32_Display_Buffer_Access is
     new Ada.Unchecked_Conversion
       (Source => SDL.Video.Pixels.ARGB_8888_Access.Pointer,
        Target => RGB32_Display_Buffer_Access);

   function To_Public_RGB32_Display_Buffer_Access is
     new Ada.Unchecked_Conversion
       (Source => RGB32_Display_Buffer_Access,
        Target => Gade.Video_Buffer.RGB32_Display_Buffer_Access);

   procedure Render_Frame (Window : in out Window_Instance) is
      Pixel_Pointer : SDL.Video.Pixels.ARGB_8888_Access.Pointer;
   begin
      SDL_Texture_Lock (Window.Texture, Pixel_Pointer);
      Generate_Frame
        (To_Public_RGB32_Display_Buffer_Access
           (ARGB_8888_Pointer_To_RGB32_Display_Buffer_Access (Pixel_Pointer)));
      SDL.Video.Textures.Unlock (Window.Texture);

      SDL.Video.Renderers.Clear (Window.Renderer);
      SDL.Video.Renderers.Copy (Window.Renderer, Window.Texture);
      SDL.Video.Renderers.Present (Window.Renderer);
   end Render_Frame;

   procedure Set_FPS
     (Window : in out Window_Instance;
      FPS    :        Float)
   is
      FPS_Int        : constant Integer := Integer (FPS);
      FPS_Str_Raw    : constant String := FPS_Int'Image;
      FPS_Str_Sliced : constant String := FPS_Str_Raw (2 .. FPS_Str_Raw'Last);
   begin
      Window.Window.Set_Title ("Gade (" & FPS_Str_Sliced & " fps)");
   end Set_FPS;

   overriding
   procedure Finalize (Window : in out Window_Instance) is
   begin
      Shutdown (Window);
   end Finalize;

   procedure Shutdown (Window : in out Window_Instance) is
   begin
      if not Window.Is_Created or else Window.Is_Shutdown then
         return;
      end if;

      Put_Debug ("Window Finalize");
      SDL.Video.Textures.Finalize (Window.Texture);
      SDL.Video.Renderers.Finalize (Window.Renderer);
      SDL.Video.Windows.Finalize (Window.Window);
      Window.Is_Shutdown := True;
   end Shutdown;

end Video.Window;
