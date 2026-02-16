with Gade.Audio_Buffer; use Gade.Audio_Buffer;

package body Runtime.Main_Loop is

   procedure Create (Runner : out Instance) is
   begin
      Runner.Last_Frame_Rendered_Ticks := 0;
   end Create;

   procedure Step
     (Runner   : in out Instance;
      G        : in out Gade_Type;
      Window   : in out Window_Instance;
      Audio_IO : in out Audio.IO.Instance)
   is
      Ticks : constant Milliseconds := SDL.Timers.Ticks;
   begin
      if Ticks - Runner.Last_Frame_Rendered_Ticks >= Ticks_Per_Frame then
         Generate_And_Render (G, Window, Audio_IO);
         Runner.Last_Frame_Rendered_Ticks := Ticks;
      else
         Generate_And_Discard (G, Audio_IO);
      end if;
   end Step;

   procedure Generate_And_Render
     (G        : in out Gade_Type;
      Window   : in out Window_Instance;
      Audio_IO : in out Audio.IO.Instance)
   is
      procedure Generate_Frame (Buffer : RGB32_Display_Buffer_Access);
      procedure Generate_Frame (Buffer : RGB32_Display_Buffer_Access) is
      begin
         Generate (G, Buffer, Audio_IO);
      end Generate_Frame;

      procedure Render_Frame is new Video.Window.Render_Frame (Generate_Frame);
   begin
      Render_Frame (Window);
   end Generate_And_Render;

   procedure Generate_And_Discard
     (G        : in out Gade_Type;
      Audio_IO : in out Audio.IO.Instance)
   is
      Null_Buffer : aliased RGB32_Display_Buffer;
      Buffer_Access : constant RGB32_Display_Buffer_Access
        := Null_Buffer'Unchecked_Access;
   begin
      Generate (G, Buffer_Access, Audio_IO);
   end Generate_And_Discard;

   procedure Generate
     (G            : in out Gade_Type;
      Video_Buffer : RGB32_Display_Buffer_Access;
      Audio_IO     : in out Audio.IO.Instance)
   is
      --  Run_For may generate up to 3 more samples than requested.
      Requested_Samples : constant Natural := Producer_Chunk_Samples - 3;
      --  Audio samples generated for the current queued block.
      Actual_Samples    : Natural;
      Frame_Finished    : Boolean := False;

      procedure Generate_Samples (Audio_Buffer : Audio_Buffer_Access;
                                  Count        : out Natural);
      procedure Generate_Samples (Audio_Buffer : Audio_Buffer_Access;
                                  Count        : out Natural) is
      begin
         Run_For (G,
                  Requested_Samples,
                  Actual_Samples,
                  Video_Buffer,
                  Audio_Buffer,
                  Frame_Finished);
         Count := Actual_Samples;
      end Generate_Samples;

      procedure Queue is new Audio.IO.Queue_Asynchronously (Generate_Samples);
   begin
      while not Frame_Finished loop
         Queue (Audio_IO);
      end loop;
   end Generate;

end Runtime.Main_Loop;
