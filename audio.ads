with Buffers, Buffers.Bounded, Buffers.Circular, Buffers.Protected_Blocking_Queue;
with Buffers.Protected_Cursor_Ring;

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

   package Sample_Buffers is new Buffers.Bounded (Gade.Audio_Buffer.Stereo_Sample);

   package Bounded_Float_Buffers is new Buffers.Bounded (Float_Frame);
   package Circular_Float_Buffers is new Buffers.Circular (Float_Frame);
   --  package Protected_Circular_Float_Buffers is new Buffers.Protected_Blocking_Queue (Float_Frame);

   subtype Video_Frame_Sample_Buffer is
     Sample_Buffers.Bounded_Buffer (Gade.Audio_Buffer.Maximum_Samples);

   function Data_Access (Buff : access Video_Frame_Sample_Buffer)
                         return Gade.Audio_Buffer.Audio_Buffer_Access;

   type Bounded_Buffer_Access is access all Video_Frame_Sample_Buffer;

   package Devices is new SDL.Audio.Devices
     (Frame_Type   => Float_Frame,
      Buffer_Index => Positive,
      Buffer_Type  => Bounded_Float_Buffers.Data_Container);

   --  TODO: Better names
   package Blocking_Frame_Buffers is new Buffers.Protected_Blocking_Queue (Bounded_Buffer_Access);
   package Cursor_Ring_Frame_Buffers is new Buffers.Protected_Cursor_Ring (Float_Frame);

   type Free_Frame_Buffer_Access is access all Blocking_Frame_Buffers.Protected_Circular_Buffer;
   type Busy_Frame_Buffer_Access is access all Blocking_Frame_Buffers.Protected_Circular_Buffer;
   type Ring_Buffer_Access is access all Cursor_Ring_Frame_Buffers.Protected_Circular_Buffer;

   --  TODO: Location is temporary, might be dynamic
   --  (Consumer_Samples_Per_Pull - 1) / Min_Producer_Resampled_Samples_Per_Block + 1;
   Frame_Buffer_Count : constant := 3;



end Audio;
