with Ada.Unchecked_Conversion;

package body Audio is

   function Data_Access (Buff : access Stereo_Sample_Buffer)
                         return Audio_Buffer_Access
   is
      type Stereo_Sample_Access is access all Stereo_Sample;

      function Convert is new Ada.Unchecked_Conversion
        (Source => Stereo_Sample_Access,
         Target => Gade.Audio_Buffer.Audio_Buffer_Access);
   begin
      return Convert (Buff.Data_Access.all (1)'Access);
   end Data_Access;

end Audio;
