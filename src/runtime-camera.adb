with Ada.Exceptions;           use Ada.Exceptions;
with Ada.Strings;             use Ada.Strings;
with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;

with Interfaces;
with Interfaces.C;

with SDL.Log;                 use SDL.Log;
with SDL.Video.Pixel_Formats;
with SDL.Video.Pixels;
with SDL.Video.Surfaces;

package body Runtime.Camera is
   use type Interfaces.C.int;
   use type SDL.Cameras.Permission_States;
   use type SDL.Cameras.Positions;
   use type SDL.Video.Surfaces.Surface;

   package Surface_Pixels is new SDL.Video.Surfaces.Pixel_Data
     (Element         => SDL.Video.Pixels.ARGB_8888,
      Element_Pointer => SDL.Video.Pixels.ARGB_8888_Access.Pointer);

   Desired_Spec : constant SDL.Cameras.Spec :=
     (Format                => SDL.Video.Pixel_Formats.Pixel_Format_ARGB_8888,
      Colour_Space          => SDL.Cameras.Unknown_Colour_Space,
      Width                 => Interfaces.C.int (Gade.Camera.Capture_Width),
      Height                => Interfaces.C.int (Gade.Camera.Capture_Height),
      Framerate_Numerator   => 30,
      Framerate_Denominator => 1);

   procedure Free is new Ada.Unchecked_Deallocation
     (Object => State,
      Name   => State_Access);

   function Pattern_Color
     (X : Gade.Camera.Column_Index;
      Y : Gade.Camera.Row_Index) return Gade.Camera.Pixel_Value;

   procedure Generate_Fallback (Frame : out Gade.Camera.Bitmap);

   function Camera_Label (Device : SDL.Cameras.ID) return String;

   function Select_Device
     (Devices : SDL.Cameras.ID_Lists) return SDL.Cameras.ID;

   function To_Pixel_Value
     (X     : Gade.Camera.Column_Index;
      Y     : Gade.Camera.Row_Index;
      Pixel : SDL.Video.Pixels.ARGB_8888) return Gade.Camera.Pixel_Value;

   procedure Log_Permission_State (Provider_State : in out State);

   procedure Update_Last_Frame
     (Provider_State : in out State;
      Surface        : in out SDL.Video.Surfaces.Surface);

   procedure Refresh_From_Device (Provider_State : in out State);

   function Pattern_Color
     (X : Gade.Camera.Column_Index;
      Y : Gade.Camera.Row_Index) return Gade.Camera.Pixel_Value
   is
      Center_X : constant Integer := Gade.Camera.Capture_Width / 2;
      Center_Y : constant Integer := Gade.Camera.Capture_Height / 2;
      DX       : constant Integer := Integer (X) - Center_X;
      DY       : constant Integer := Integer (Y) - Center_Y;

      Checker_Is_Light : constant Boolean :=
        (((Integer (X) / 8) + (Integer (Y) / 8)) mod 2) = 0;
      On_Crosshair : constant Boolean := abs (DX) <= 2 or else abs (DY) <= 2;
      On_Diagonal : constant Boolean :=
        abs (abs (DX) - abs (DY)) <= 2;
      In_Center_Diamond : constant Boolean := abs (DX) + abs (DY) <= 18;
   begin
      if On_Crosshair then
         return 3;
      elsif On_Diagonal then
         return 2;
      elsif In_Center_Diamond then
         return 0;
      elsif Checker_Is_Light then
         return 1;
      else
         return 2;
      end if;
   end Pattern_Color;

   procedure Generate_Fallback (Frame : out Gade.Camera.Bitmap) is
   begin
      for Y in Frame'Range (1) loop
         for X in Frame'Range (2) loop
            Frame (Y, X) := Pattern_Color (X, Y);
         end loop;
      end loop;
   end Generate_Fallback;

   function Camera_Label (Device : SDL.Cameras.ID) return String is
      Name : constant String := SDL.Cameras.Name (Device);
   begin
      if Name /= "" then
         return Name;
      else
         return "unnamed camera";
      end if;
   end Camera_Label;

   function Select_Device
     (Devices : SDL.Cameras.ID_Lists) return SDL.Cameras.ID
   is
      Selected : SDL.Cameras.ID := Devices (Devices'First);
   begin
      for Device of Devices loop
         if SDL.Cameras.Position (Device) = SDL.Cameras.Front_Facing then
            Selected := Device;
            exit;
         end if;
      end loop;

      return Selected;
   end Select_Device;

   function To_Pixel_Value
     (X     : Gade.Camera.Column_Index;
      Y     : Gade.Camera.Row_Index;
      Pixel : SDL.Video.Pixels.ARGB_8888) return Gade.Camera.Pixel_Value
   is
      Bayer_4x4 : constant array (Natural range 0 .. 3, Natural range 0 .. 3) of Natural :=
        [[0, 8, 2, 10],
         [12, 4, 14, 6],
         [3, 11, 1, 9],
         [15, 7, 13, 5]];
      Luma : constant Integer :=
        (77 * Integer (Pixel.Red)
         + 150 * Integer (Pixel.Green)
         + 29 * Integer (Pixel.Blue)
         + 128) / 256;
      Darkness : constant Float := Float (255 - Luma) * 3.0 / 255.0;
      Threshold : constant Float :=
        (Float (Bayer_4x4 (Natural (Y) mod 4, Natural (X) mod 4)) + 0.5) / 16.0;
      Shade : Integer := Integer (Darkness);
   begin
      --  Ordered dithering gives the 2-bit host-camera image a much closer
      --  match to the characteristic stippled look of Game Boy Camera output.
      if Shade < 3 and then Darkness - Float (Shade) > Threshold then
         Shade := Shade + 1;
      end if;

      return Gade.Camera.Pixel_Value (Shade);
   end To_Pixel_Value;

   procedure Log_Permission_State (Provider_State : in out State) is
      Permission : constant SDL.Cameras.Permission_States :=
        Provider_State.Device.Permission_State;
   begin
      if Provider_State.Permission_State_Seen
        and then Permission = Provider_State.Last_Permission_State
      then
         return;
      end if;

      case Permission is
         when SDL.Cameras.Approved =>
            Put_Info ("SDL camera permission approved");
         when SDL.Cameras.Pending =>
            Put_Info ("SDL camera permission pending");
         when SDL.Cameras.Denied =>
            Put_Warn ("SDL camera permission denied; using synthetic fallback");
      end case;

      Provider_State.Permission_State_Seen := True;
      Provider_State.Last_Permission_State := Permission;
   end Log_Permission_State;

   procedure Update_Last_Frame
     (Provider_State : in out State;
      Surface        : in out SDL.Video.Surfaces.Surface)
   is
      Frame_Size : constant SDL.Sizes := Surface.Size;
      Frame_Width, Frame_Height : Positive;
      Locked : Boolean := False;
   begin
      if Frame_Size.Width <= 0 or else Frame_Size.Height <= 0 then
         return;
      end if;

      Frame_Width := Positive (Frame_Size.Width);
      Frame_Height := Positive (Frame_Size.Height);

      if Surface.Must_Lock then
         Surface.Lock;
         Locked := True;
      end if;

      for Y in Gade.Camera.Row_Index loop
         declare
            Source_Y : constant SDL.Coordinate :=
              SDL.Coordinate
                (Y * Frame_Height / Gade.Camera.Capture_Height);
            Row_Pointer : constant SDL.Video.Pixels.ARGB_8888_Access.Pointer :=
              Surface_Pixels.Get_Row (Surface, Source_Y);
         begin
            for X in Gade.Camera.Column_Index loop
               declare
                  Source_X : constant Interfaces.C.ptrdiff_t :=
                    Interfaces.C.ptrdiff_t
                      (X * Frame_Width / Gade.Camera.Capture_Width);
                  Pixel_Pointer : constant SDL.Video.Pixels.ARGB_8888_Access.Pointer :=
                    SDL.Video.Pixels.ARGB_8888_Access."+" (Row_Pointer, Source_X);
               begin
                  Provider_State.Last_Frame (Y, X) :=
                    To_Pixel_Value (X, Y, Pixel_Pointer.all);
               end;
            end loop;
         end;
      end loop;

      if Locked then
         Surface.Unlock;
      end if;

      Provider_State.Have_Last_Frame := True;
      Provider_State.Capture_Error_Seen := False;

      if not Provider_State.Seen_Real_Frame then
         Put_Info ("SDL camera frames active");
         Provider_State.Seen_Real_Frame := True;
      end if;
   exception
      when others =>
         if Locked then
            Surface.Unlock;
         end if;
         raise;
   end Update_Last_Frame;

   procedure Refresh_From_Device (Provider_State : in out State) is
      Timestamp_NS   : SDL.Cameras.Timestamp_Nanoseconds := 0;
      Surface        : SDL.Video.Surfaces.Surface := SDL.Video.Surfaces.Null_Surface;
      Latest_Surface : SDL.Video.Surfaces.Surface := SDL.Video.Surfaces.Null_Surface;
   begin
      if SDL.Cameras.Is_Null (Provider_State.Device) then
         return;
      end if;

      Log_Permission_State (Provider_State);

      if Provider_State.Last_Permission_State /= SDL.Cameras.Approved then
         return;
      end if;

      loop
         Surface := Provider_State.Device.Acquire_Frame (Timestamp_NS);
         exit when Surface = SDL.Video.Surfaces.Null_Surface;

         if Latest_Surface /= SDL.Video.Surfaces.Null_Surface then
            Provider_State.Device.Release_Frame (Latest_Surface);
         end if;

         Latest_Surface := Surface;
      end loop;
      pragma Unreferenced (Timestamp_NS);

      if Latest_Surface = SDL.Video.Surfaces.Null_Surface then
         return;
      end if;

      begin
         Update_Last_Frame (Provider_State, Latest_Surface);
      exception
         when others =>
            Provider_State.Device.Release_Frame (Latest_Surface);
            raise;
      end;

      Provider_State.Device.Release_Frame (Latest_Surface);
   end Refresh_From_Device;

   procedure Create (Provider : in out Instance) is
      Devices       : constant SDL.Cameras.ID_Lists := SDL.Cameras.Get_Cameras;
      Selected      : SDL.Cameras.ID;
      Actual_Format : SDL.Cameras.Spec;
      Driver_Name   : constant String := SDL.Cameras.Current_Driver_Name;
   begin
      Shutdown (Provider);

      Provider.State := new State;

      if Driver_Name /= "" then
         Put_Debug ("SDL camera driver: " & Driver_Name);
      end if;

      if Devices'Length = 0 then
         Put_Warn ("No SDL camera devices detected; using synthetic fallback");
         return;
      end if;

      Selected := Select_Device (Devices);
      Put_Info ("Opening SDL camera: " & Camera_Label (Selected));
      Provider.State.Device.Open (Selected, Desired_Spec);

      if Provider.State.Device.Get_Format (Actual_Format) then
         Put_Info
           ("SDL camera stream: "
            & Trim (Integer (Actual_Format.Width)'Image, Left)
            & "x"
            & Trim (Integer (Actual_Format.Height)'Image, Left)
            & " "
            & SDL.Video.Pixel_Formats.Image (Actual_Format.Format));
      end if;

      Log_Permission_State (Provider.State.all);
   exception
      when E : others =>
         Shutdown (Provider);
         Put_Warn
           ("Failed to initialize SDL camera: "
            & Exception_Message (E)
            & "; using synthetic fallback");
   end Create;

   procedure Shutdown (Provider : in out Instance) is
   begin
      if Provider.State /= null then
         Free (Provider.State);
         Provider.State := null;
      end if;
   end Shutdown;

   overriding
   procedure Capture_Frame
     (Provider : Instance;
      Frame    : out Gade.Camera.Bitmap)
   is
   begin
      if Provider.State /= null then
         begin
            Refresh_From_Device (Provider.State.all);
         exception
            when E : others =>
               if not Provider.State.Capture_Error_Seen then
                  Put_Warn
                    ("SDL camera frame capture failed: "
                     & Exception_Message (E)
                     & "; reusing cached frame or fallback");
                  Provider.State.Capture_Error_Seen := True;
               end if;
         end;

         if Provider.State.Have_Last_Frame then
            Frame := Provider.State.Last_Frame;
            return;
         end if;
      end if;

      Generate_Fallback (Frame);
   end Capture_Frame;

end Runtime.Camera;
