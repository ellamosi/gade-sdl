with Runtime.Main_Loop;
with SDL.Log; use SDL.Log;

package body Audio.IO is

   procedure Create (Self : aliased out Instance) is
   begin
      pragma Unreferenced (Self);

      Put_Info ("Audio is temporarily disabled during the SDL3 Phase 4 port.");
   end Create;

   procedure Queue_Asynchronously (Self : in out Instance) is
      Buffer       : aliased Stereo_Sample_Buffer (Runtime.Main_Loop.Producer_Chunk_Samples);
      Frame_Count  : Natural;
   begin
      pragma Unreferenced (Self);

      Buffer.Set_Length (Buffer.Capacity);
      Generate (Data_Access (Buffer'Access), Frame_Count);
      Buffer.Set_Length (Frame_Count);
   end Queue_Asynchronously;

   overriding
   procedure Finalize (Self : in out Instance) is
   begin
      Shutdown (Self);
   end Finalize;

   procedure Shutdown (Self : in out Instance) is
   begin
      pragma Unreferenced (Self);
   end Shutdown;

end Audio.IO;
