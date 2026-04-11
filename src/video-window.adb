with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Streams;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;

with Interfaces;

with System;
with System.Address_To_Access_Conversions;

with SDL.Log; use SDL.Log;
with SDL.Platform;
with SDL.Properties;
with SDL.Video.Pixel_Formats;
with SDL.Video.Windows.Makers;

package body Video.Window is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;
   use type SDL.Platform.Platforms;
   use type SDL.GPU.Texture_Formats;
   use type SDL.Video.Windows.Window_Flags;
   use type System.Address;

   Display_Width_U32 : constant Interfaces.Unsigned_32 :=
     Interfaces.Unsigned_32 (Display_Width);
   Display_Height_U32 : constant Interfaces.Unsigned_32 :=
     Interfaces.Unsigned_32 (Display_Height);
   Frame_Byte_Size : constant Interfaces.Unsigned_32 :=
     Interfaces.Unsigned_32 (RGB32_Display_Buffer'Size / System.Storage_Unit);

   type Pixel_Format_Candidate_Arrays is
     array (Positive range <>) of SDL.Video.Pixel_Formats.Pixel_Format_Names;

   Source_Texture_Format_Candidates : constant Pixel_Format_Candidate_Arrays :=
     [SDL.Video.Pixel_Formats.Pixel_Format_RGBA_8888,
      SDL.Video.Pixel_Formats.Pixel_Format_BGRA_8888,
      SDL.Video.Pixel_Formats.Pixel_Format_ARGB_8888,
      SDL.Video.Pixel_Formats.Pixel_Format_ABGR_8888,
      SDL.Video.Pixel_Formats.Pixel_Format_RGBX_8888,
      SDL.Video.Pixel_Formats.Pixel_Format_BGRX_8888,
      SDL.Video.Pixel_Formats.Pixel_Format_XRGB_8888,
      SDL.Video.Pixel_Formats.Pixel_Format_XBGR_8888];

   Create_Metal_Allow_Macfamily1_Property : constant String :=
     "SDL.gpu.device.create.metal.allowmacfamily1";

   Vertex_Shader_Source : constant String :=
     "#include <metal_stdlib>" & LF &
     "using namespace metal;" & LF &
     LF &
     "struct Vertex_Output {" & LF &
     "    float2 uv;" & LF &
     "    float4 position [[position]];" & LF &
     "};" & LF &
     LF &
     "vertex Vertex_Output main0(uint vertex_id [[vertex_id]]) {" & LF &
     "    const uint indices[6] = {0, 1, 2, 0, 2, 3};" & LF &
     "    const float2 positions[4] = {" & LF &
     "        float2(-1.0,  1.0)," & LF &
     "        float2( 1.0,  1.0)," & LF &
     "        float2( 1.0, -1.0)," & LF &
     "        float2(-1.0, -1.0)" & LF &
     "    };" & LF &
     "    const float2 uvs[4] = {" & LF &
     "        float2(0.0, 0.0)," & LF &
     "        float2(1.0, 0.0)," & LF &
     "        float2(1.0, 1.0)," & LF &
     "        float2(0.0, 1.0)" & LF &
     "    };" & LF &
     LF &
     "    Vertex_Output result;" & LF &
     "    const uint vertex_index = indices[vertex_id];" & LF &
     "    result.uv = uvs[vertex_index];" & LF &
     "    result.position = float4(positions[vertex_index], 0.0, 1.0);" & LF &
     "    return result;" & LF &
     "}" & LF;

   Fragment_Shader_Source : constant String :=
     "#include <metal_stdlib>" & LF &
     "using namespace metal;" & LF &
     LF &
     "struct Vertex_Output {" & LF &
     "    float2 uv;" & LF &
     "    float4 position [[position]];" & LF &
     "};" & LF &
     LF &
     "fragment float4 main1(Vertex_Output input [[stage_in]]," & LF &
     "                      texture2d<float> source_texture [[texture(0)]]," & LF &
     "                      sampler source_sampler [[sampler(0)]]) {" & LF &
     "    constexpr float3 palette[4] = {" & LF &
     "        float3(224.0 / 255.0, 248.0 / 255.0, 208.0 / 255.0)," & LF &
     "        float3(136.0 / 255.0, 192.0 / 255.0, 112.0 / 255.0)," & LF &
     "        float3( 52.0 / 255.0, 104.0 / 255.0,  86.0 / 255.0)," & LF &
     "        float3(  8.0 / 255.0,  24.0 / 255.0,  32.0 / 255.0)" & LF &
     "    };" & LF &
     "    const float grayscale = clamp(source_texture.sample(source_sampler, input.uv).r, 0.0, 1.0);" & LF &
     "    const float shade = min(floor(((1.0 - grayscale) * 3.0) + 0.5), 3.0);" & LF &
     "    const uint index = uint(shade);" & LF &
     "    return float4(palette[index], 1.0);" & LF &
     "}" & LF;

   package RGB32_Display_Buffer_Conversions is new
     System.Address_To_Access_Conversions (RGB32_Display_Buffer);

   subtype Internal_RGB32_Display_Buffer_Access is
     RGB32_Display_Buffer_Conversions.Object_Pointer;

   function To_Public_RGB32_Display_Buffer_Access is
     new Ada.Unchecked_Conversion
       (Source => Internal_RGB32_Display_Buffer_Access,
        Target => Gade.Video_Buffer.RGB32_Display_Buffer_Access);

   function To_Stream_Elements
     (Text : in String) return Ada.Streams.Stream_Element_Array;

   function To_Stream_Elements
     (Text : in String) return Ada.Streams.Stream_Element_Array
   is
      Result : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
      Offset : Ada.Streams.Stream_Element_Offset := Result'First;
   begin
      for Character_Of of Text loop
         Result (Offset) :=
           Ada.Streams.Stream_Element (Character'Pos (Character_Of));
         Offset := Offset + Ada.Streams.Stream_Element_Offset (1);
      end loop;

      return Result;
   end To_Stream_Elements;

   function Window_Flags_For
     (Driver : in String) return SDL.Video.Windows.Window_Flags
   is
      Flags : SDL.Video.Windows.Window_Flags :=
        SDL.Video.Windows.Windowed or SDL.Video.Windows.High_Pixel_Density;
   begin
      if Driver = "metal" then
         Flags := Flags or SDL.Video.Windows.Metal;
      elsif Driver = "vulkan" then
         Flags := Flags or SDL.Video.Windows.Vulkan;
      end if;

      return Flags;
   end Window_Flags_For;

   function Supports_Format
     (Supported : in SDL.GPU.Shader_Formats;
      Desired   : in SDL.GPU.Shader_Formats) return Boolean
   is
     ((Supported and Desired) = Desired);

   function Select_Source_Texture_Format
     (Device : in SDL.GPU.Device) return SDL.GPU.Texture_Formats
   is
      Texture_Format : SDL.GPU.Texture_Formats;
   begin
      for Candidate of Source_Texture_Format_Candidates loop
         Texture_Format := SDL.GPU.Texture_Format_From_Pixel_Format (Candidate);

         if Texture_Format /= SDL.GPU.Invalid_Texture_Format
           and then SDL.GPU.Texture_Format_Texel_Block_Size (Texture_Format) = 4
           and then SDL.GPU.Texture_Supports_Format
             (Device,
              Texture_Format,
              SDL.GPU.Texture_2D,
              SDL.GPU.Texture_Usage_Sampler)
         then
            Put_Debug
              ("GPU source texture pixel format: "
               & SDL.Video.Pixel_Formats.Image (Candidate));
            return Texture_Format;
         end if;
      end loop;

      return SDL.GPU.Invalid_Texture_Format;
   end Select_Source_Texture_Format;

   procedure Release_Claimed_Window (Window : in out Window_Instance) is
   begin
      if Window.Is_Window_Claimed and then not SDL.GPU.Is_Null (Window.Device) then
         SDL.GPU.Release_Window (Window.Device, Window.Window);
         Window.Is_Window_Claimed := False;
      end if;
   end Release_Claimed_Window;

   procedure Destroy_GPU_Resources (Window : in out Window_Instance) is
   begin
      SDL.GPU.Destroy (Window.Pipeline);
      SDL.GPU.Destroy (Window.Fragment_Shader);
      SDL.GPU.Destroy (Window.Vertex_Shader);
      SDL.GPU.Destroy (Window.Sampler);
      SDL.GPU.Destroy (Window.Source_Texture);
      SDL.GPU.Destroy (Window.Upload_Buffer);
   end Destroy_GPU_Resources;

   procedure Create (Window : out Window_Instance) is
      Supported_Shader_Formats : SDL.GPU.Shader_Formats;
      Source_Texture_Format    : SDL.GPU.Texture_Formats;
      Swapchain_Format         : SDL.GPU.Texture_Formats;
      Present_Mode             : SDL.GPU.Present_Modes := SDL.GPU.Immediate;
      Empty_Vertex_Buffers :
        constant SDL.GPU.Vertex_Buffer_Description_Arrays (1 .. 0) :=
          [others => <>];
      Empty_Vertex_Attributes :
        constant SDL.GPU.Vertex_Attribute_Arrays (1 .. 0) :=
          [others => <>];
   begin
      if SDL.Platform.Get = SDL.Platform.Mac_OS_X then
         declare
            Device_Properties : SDL.Properties.Property_Set;
         begin
            SDL.Properties.Create (Device_Properties);
            Device_Properties.Set_String
              (SDL.GPU.Create_Name_Property,
               "metal");
            Device_Properties.Set_Boolean
              (SDL.GPU.Create_Shader_MSL_Property,
               True);
            Device_Properties.Set_Boolean
              (Create_Metal_Allow_Macfamily1_Property,
               True);
            SDL.GPU.Create_With_Properties (Window.Device, Device_Properties);
         end;
      else
         SDL.GPU.Create
           (Window.Device,
            Formats => SDL.GPU.Default_Shader_Formats);
      end if;
      Put_Debug ("GPU driver: " & SDL.GPU.Driver_Name (Window.Device));

      Supported_Shader_Formats :=
        SDL.GPU.Supported_Shader_Formats (Window.Device);
      if not Supports_Format (Supported_Shader_Formats, SDL.GPU.MSL_Shader_Format) then
         raise SDL.GPU.GPU_Error
           with "gade-sdl currently requires an SDL GPU backend with MSL shader support";
      end if;

      Source_Texture_Format := Select_Source_Texture_Format (Window.Device);
      if Source_Texture_Format = SDL.GPU.Invalid_Texture_Format then
         raise SDL.GPU.GPU_Error
           with "Unable to find a supported 4-byte SDL GPU sampler format for emulator frame uploads";
      end if;

      SDL.Video.Windows.Makers.Create
        (Win    => Window.Window,
         Title  => "Gade",
         X      => SDL.Video.Windows.Centered_Window_Position,
         Y      => SDL.Video.Windows.Centered_Window_Position,
         Width  => Display_Width * 2,
         Height => Display_Height * 2,
         Flags  => Window_Flags_For (SDL.GPU.Driver_Name (Window.Device)));

      SDL.GPU.Claim_Window (Window.Device, Window.Window);
      Window.Is_Window_Claimed := True;

      if not SDL.GPU.Supports_Composition
          (Window.Device, Window.Window, SDL.GPU.Swapchain_SDR)
      then
         raise SDL.GPU.GPU_Error
           with "The selected SDL GPU backend does not support SDR swapchains";
      end if;

      if not SDL.GPU.Supports_Present_Mode
          (Window.Device, Window.Window, SDL.GPU.Immediate)
      then
         Present_Mode := SDL.GPU.V_Sync;
      end if;

      if not SDL.GPU.Supports_Present_Mode
          (Window.Device, Window.Window, Present_Mode)
      then
         raise SDL.GPU.GPU_Error
           with "The selected SDL GPU backend does not support an SDL GPU present mode usable by gade-sdl";
      end if;

      SDL.GPU.Set_Swapchain_Parameters
        (Window.Device,
         Window.Window,
         Composition  => SDL.GPU.Swapchain_SDR,
         Present_Mode => Present_Mode);
      SDL.GPU.Set_Allowed_Frames_In_Flight (Window.Device, 1);

      Swapchain_Format :=
        SDL.GPU.Get_Swapchain_Texture_Format (Window.Device, Window.Window);
      if Swapchain_Format = SDL.GPU.Invalid_Texture_Format then
         raise SDL.GPU.GPU_Error
           with "Unable to determine the SDL GPU swapchain texture format";
      end if;

      SDL.GPU.Create_Transfer_Buffer
        (Window.Upload_Buffer,
         Window.Device,
         SDL.GPU.Upload,
         Frame_Byte_Size);
      SDL.GPU.Create_Texture
        (Window.Source_Texture,
         Window.Device,
         Source_Texture_Format,
         SDL.GPU.Texture_Usage_Sampler,
         Display_Width_U32,
         Display_Height_U32);
      SDL.GPU.Create_Sampler
        (Window.Sampler,
         Window.Device,
         Min_Filter     => SDL.GPU.Nearest,
         Mag_Filter     => SDL.GPU.Nearest,
         Address_Mode_U => SDL.GPU.Clamp_To_Edge,
         Address_Mode_V => SDL.GPU.Clamp_To_Edge,
         Address_Mode_W => SDL.GPU.Clamp_To_Edge);
      SDL.GPU.Create_Shader
        (Window.Vertex_Shader,
         Window.Device,
         To_Stream_Elements (Vertex_Shader_Source),
         "main0",
         SDL.GPU.MSL_Shader_Format,
         SDL.GPU.Vertex_Shader);
      SDL.GPU.Create_Shader
        (Window.Fragment_Shader,
         Window.Device,
         To_Stream_Elements (Fragment_Shader_Source),
         "main1",
         SDL.GPU.MSL_Shader_Format,
         SDL.GPU.Fragment_Shader,
         Num_Samplers => 1);
      SDL.GPU.Create_Graphics_Pipeline
        (Window.Pipeline,
         Window.Device,
         Window.Vertex_Shader,
         Window.Fragment_Shader,
         Empty_Vertex_Buffers,
         Empty_Vertex_Attributes,
         SDL.GPU.Triangle_List,
         [0 => (Format => Swapchain_Format, others => <>)]);

      Window.Is_Created := True;
      Window.Is_Shutdown := False;
   exception
      when others =>
         Destroy_GPU_Resources (Window);
         Release_Claimed_Window (Window);
         SDL.Video.Windows.Finalize (Window.Window);
         SDL.GPU.Destroy (Window.Device);
         Window.Is_Created := False;
         Window.Is_Shutdown := False;
         raise;
   end Create;

   procedure Render_Frame (Window : in out Window_Instance) is
      use type RGB32_Display_Buffer_Conversions.Object_Pointer;

      Mapped_Frame  : System.Address := System.Null_Address;
      Buffer_Access : RGB32_Display_Buffer_Conversions.Object_Pointer;
      Command       : SDL.GPU.Command_Buffer;
      Copy_Pass     : SDL.GPU.Copy_Pass;
      Render_Pass   : SDL.GPU.Render_Pass;
      Swapchain     : SDL.GPU.Texture;
      Width         : SDL.Natural_Dimension;
      Height        : SDL.Natural_Dimension;
      Copy_Pass_Open   : Boolean := False;
      Render_Pass_Open : Boolean := False;
      Debug_Group_Open : Boolean := False;
      Swapchain_Acquired : Boolean := False;
   begin
      Mapped_Frame := SDL.GPU.Map (Window.Upload_Buffer, Cycle => True);
      Buffer_Access := RGB32_Display_Buffer_Conversions.To_Pointer (Mapped_Frame);
      if Buffer_Access = null then
         raise SDL.GPU.GPU_Error
           with "Unable to reinterpret the SDL GPU upload buffer as a display frame";
      end if;

      Generate_Frame (To_Public_RGB32_Display_Buffer_Access (Buffer_Access));
      SDL.GPU.Unmap (Window.Upload_Buffer);
      Mapped_Frame := System.Null_Address;

      Command := SDL.GPU.Acquire_Command_Buffer (Window.Device);
      SDL.GPU.Push_Debug_Group (Command, "frame");
      Debug_Group_Open := True;

      Copy_Pass := SDL.GPU.Begin_Copy_Pass (Command);
      Copy_Pass_Open := True;
      SDL.GPU.Upload_To_Texture
        (Copy_Pass,
         SDL.GPU.Make_Texture_Transfer_Info
           (Window.Upload_Buffer,
            Pixels_Per_Row => Display_Width_U32,
            Rows_Per_Layer => Display_Height_U32),
         SDL.GPU.Make_Texture_Region
           (Window.Source_Texture, Display_Width_U32, Display_Height_U32),
         Cycle => True);
      SDL.GPU.End_Pass (Copy_Pass);
      Copy_Pass_Open := False;

      if not SDL.GPU.Wait_And_Acquire_Swapchain_Texture
          (Command, Window.Window, Swapchain, Width, Height)
      then
         SDL.GPU.Pop_Debug_Group (Command);
         Debug_Group_Open := False;
         SDL.GPU.Cancel (Command);
         return;
      end if;
      Swapchain_Acquired := True;

      Render_Pass :=
        SDL.GPU.Begin_Render_Pass
          (Command,
           SDL.GPU.Make_Color_Target_Info
             (Target          => Swapchain,
              Clear_To        =>
                (Red => 0.0, Green => 0.0, Blue => 0.0, Alpha => 1.0),
              Load_Operation  => SDL.GPU.Clear,
              Store_Operation => SDL.GPU.Store));
      Render_Pass_Open := True;

      SDL.GPU.Set_Viewport
        (Render_Pass,
         (X         => 0.0,
          Y         => 0.0,
          Width     => Float (Width),
          Height    => Float (Height),
          Min_Depth => 0.0,
          Max_Depth => 1.0));
      SDL.GPU.Bind_Pipeline (Render_Pass, Window.Pipeline);
      SDL.GPU.Bind_Fragment_Samplers
        (Render_Pass,
         0,
         [0 => SDL.GPU.Make_Texture_Sampler_Binding
            (Window.Source_Texture, Window.Sampler)]);
      SDL.GPU.Draw_Primitives (Render_Pass, 6);
      SDL.GPU.End_Pass (Render_Pass);
      Render_Pass_Open := False;

      SDL.GPU.Pop_Debug_Group (Command);
      Debug_Group_Open := False;
      SDL.GPU.Submit (Command);
   exception
      when others =>
         if Mapped_Frame /= System.Null_Address then
            SDL.GPU.Unmap (Window.Upload_Buffer);
         end if;

         if Copy_Pass_Open then
            SDL.GPU.End_Pass (Copy_Pass);
         end if;

         if Render_Pass_Open then
            SDL.GPU.End_Pass (Render_Pass);
         end if;

         if not SDL.GPU.Is_Null (Command) then
            begin
               if Debug_Group_Open then
                  SDL.GPU.Pop_Debug_Group (Command);
               end if;
            exception
               when others =>
                  null;
            end;

            begin
               if Swapchain_Acquired then
                  SDL.GPU.Submit (Command);
               else
                  SDL.GPU.Cancel (Command);
               end if;
            exception
               when others =>
                  null;
            end;
         end if;

         raise;
   end Render_Frame;

   procedure Set_FPS
     (Window : in out Window_Instance;
      FPS    :        Float)
   is
      FPS_Int : constant Natural := Natural (FPS);
      FPS_Str : constant String := Trim (FPS_Int'Image, Ada.Strings.Left);
   begin
      Window.Window.Set_Title ("Gade (" & FPS_Str & " fps)");
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

      if not SDL.GPU.Is_Null (Window.Device) then
         SDL.GPU.Wait_For_Idle (Window.Device);
      end if;

      Destroy_GPU_Resources (Window);
      Release_Claimed_Window (Window);
      SDL.Video.Windows.Finalize (Window.Window);
      SDL.GPU.Destroy (Window.Device);

      Window.Is_Shutdown := True;
   end Shutdown;

end Video.Window;
