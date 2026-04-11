with Gade.Camera;

package Runtime.Camera is

   type Instance is new Gade.Camera.Provider_Interface with private;

   overriding
   procedure Capture_Frame
     (Provider : Instance;
      Frame    : out Gade.Camera.Bitmap);

private

   type Instance is new Gade.Camera.Provider_Interface with null record;

end Runtime.Camera;
