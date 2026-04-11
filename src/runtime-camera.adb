package body Runtime.Camera is

   function Pattern_Color
     (X : Gade.Camera.Column_Index;
      Y : Gade.Camera.Row_Index) return Gade.Camera.Pixel_Value;

   overriding
   procedure Capture_Frame
     (Provider : Instance;
      Frame    : out Gade.Camera.Bitmap)
   is
      pragma Unreferenced (Provider);
   begin
      for Y in Frame'Range (1) loop
         for X in Frame'Range (2) loop
            Frame (Y, X) := Pattern_Color (X, Y);
         end loop;
      end loop;
   end Capture_Frame;

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
      --  Frontend-specific camera test card: checkerboard field with a bright
      --  crosshair/diagonals and a dark center diamond.
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

end Runtime.Camera;
