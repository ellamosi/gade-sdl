with Buffers.Bounded;

with Gade.Audio_Buffer; use Gade.Audio_Buffer;

package Audio is private

   package Stereo_Sample_Buffers is new Buffers.Bounded (Gade.Audio_Buffer.Stereo_Sample);
   subtype Stereo_Sample_Buffer is Stereo_Sample_Buffers.Bounded_Buffer;

   function Data_Access (Buff : access Stereo_Sample_Buffer)
                         return Gade.Audio_Buffer.Audio_Buffer_Access;
end Audio;
