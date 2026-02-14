private package Audio.Resamplers is

   type Resampler is tagged private;

   procedure Reset
     (Self             : in out Resampler;
      Input_Frequency  : Float;
      Output_Frequency : Float);

   procedure Resample
     (Self   : in out Resampler;
      Input  : Sample_Buffers.Bounded_Buffer; --  TODO: Rename generic package instance
      Output : in out Circular_Float_Buffers.Circular_Buffer);

   procedure Set_Input_Frequency
     (Self            : in out Resampler;
      Input_Frequency : Float);

private

   type Frame_History is array (0 .. 3) of Float_Frame;

   type Resampler is tagged record
      History          : Frame_History;
      Ratio            : Float;
      Fraction         : Float;
      Input_Frequency  : Float;
      Output_Frequency : Float;
   end record;

   procedure Resample
     (Self   : in out Resampler;
      Frame  : Stereo_Sample;
      Output : in out Circular_Float_Buffers.Circular_Buffer);

end Audio.Resamplers;
