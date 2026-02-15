with Buffers.Bounded, Buffers.Ring;
with Buffers.Transactional_Ring;

with Gade.Audio_Buffer; use Gade.Audio_Buffer;
with SDL.Audio.Devices;

package Audio is private

   type Float_Frame is record
      Left, Right : Float;
   end record;

   function "+" (Left, Right : Float_Frame) return Float_Frame with Inline;

   function "-" (Left, Right : Float_Frame) return Float_Frame with Inline;

   function "*" (Left : Float_Frame; Right : Float)
                 return Float_Frame with Inline;

   function To_Float (S : Sample) return Float with Inline;

   package Stereo_Sample_Buffers is new Buffers.Bounded (Gade.Audio_Buffer.Stereo_Sample);
   subtype Stereo_Sample_Buffer is Stereo_Sample_Buffers.Bounded_Buffer;

   package Bounded_Float_Buffers is new Buffers.Bounded (Float_Frame);
   package Circular_Float_Buffers is new Buffers.Ring (Float_Frame);

   function Data_Access (Buff : access Stereo_Sample_Buffer)
                         return Gade.Audio_Buffer.Audio_Buffer_Access;

   package Devices is new SDL.Audio.Devices
     (Frame_Type   => Float_Frame,
      Buffer_Index => Positive,
      Buffer_Type  => Bounded_Float_Buffers.Data_Container);

   package Cursor_Ring_Stereo_Samples is
     new Buffers.Transactional_Ring (Gade.Audio_Buffer.Stereo_Sample);
   package Cursor_Ring_Frame_Buffers is new Buffers.Transactional_Ring (Float_Frame);

   type Source_Ring_Buffer_Access is access all Cursor_Ring_Stereo_Samples.Transactional_Ring_Buffer;
   type Ring_Buffer_Access is access all Cursor_Ring_Frame_Buffers.Transactional_Ring_Buffer;
end Audio;
