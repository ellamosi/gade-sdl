with Gade.Interfaces;   use Gade.Interfaces;
with Video.Window;       use Video.Window;
with Audio.IO;
with Gade.Video_Buffer; use Gade.Video_Buffer;

with SDL.Timers; use SDL.Timers;

package Runtime.Main_Loop is

   Producer_Chunk_Samples   : constant Natural := 2_048;

   type Instance is limited private;

   procedure Create (Runner : out Instance);

   procedure Step (Runner   : in out Instance;
                   G        : in out Gade_Type;
                   Window   : in out Window_Instance;
                   Audio_IO : in out Audio.IO.Instance);

private

   type Instance is record
      Last_Frame_Rendered_Ticks : Milliseconds;
   end record;

   procedure Generate_And_Render
     (G        : in out Gade_Type;
      Window   : in out Window_Instance;
      Audio_IO : in out Audio.IO.Instance);

   procedure Generate_And_Discard
     (G        : in out Gade_Type;
      Audio_IO : in out Audio.IO.Instance);

   procedure Generate
     (G            : in out Gade_Type;
      Video_Buffer : RGB32_Display_Buffer_Access;
      Audio_IO     : in out Audio.IO.Instance);

end Runtime.Main_Loop;
