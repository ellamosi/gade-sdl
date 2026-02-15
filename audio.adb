with Ada.Unchecked_Conversion;

package body Audio is

   function "+" (Left, Right : Float_Frame) return Float_Frame is
   begin
      return (Left.Left + Right.Left, Left.Right + Right.Right);
   end "+";

   function "-" (Left, Right : Float_Frame) return Float_Frame is
   begin
      return (Left.Left - Right.Left, Left.Right - Right.Right);
   end "-";

   function "*" (Left : Float_Frame; Right : Float) return Float_Frame is
   begin
      return (Left.Left * Right, Left.Right * Right);
   end "*";

   function To_Float (S : Sample) return Float is
   begin
      return Float (S) / Float (Sample'Last);
   end To_Float;

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
