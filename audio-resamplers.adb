package body Audio.Resamplers is

   procedure Reset
     (Self             : in out Resampler;
      Input_Frequency  : Float;
      Output_Frequency : Float)
   is
   begin
      Self.History          := (others => (0.0, 0.0));
      Self.Input_Frequency  := Input_Frequency;
      Self.Output_Frequency := Output_Frequency;
      Self.Ratio            := Input_Frequency / Output_Frequency;
      Self.Fraction         := 0.0;
   end Reset;

   procedure Resample
     (Self   : in out Resampler;
      Input  : Sample_Buffers.Bounded_Buffer;
      Output : in out Circular_Float_Buffers.Circular_Buffer)
   is
   begin
      for Frame of Input loop
         Resample (Self, Frame, Output);
      end loop;
   end Resample;

   procedure Resample
     (Self   : in out Resampler;
      Frame  : Stereo_Sample;
      Output : in out Circular_Float_Buffers.Circular_Buffer)
   is
      Mu         : Float renames Self.Fraction;
      F          : Frame_History renames Self.History;
      A, B, C, D : Float_Frame;
   begin
      F (0) := F (1);
      F (1) := F (2);
      F (2) := F (3);
      F (3) := (To_Float (Frame.Left), To_Float (Frame.Right));

      while Mu <= 1.0 and then Output.Available > 0 loop
         A := F (3) - F (2) - F (0) + F (1);
         B := F (0) - F (1) - A;
         C := F (2) - F (0);
         D := F (1);

         Output.Push (A * Mu * Mu * Mu + B * Mu * Mu + C * Mu + D);
         Mu := Mu + Self.Ratio;
      end loop;

      Mu := Mu - 1.0;
   end Resample;

   procedure Set_Input_Frequency
     (Self            : in out Resampler;
      Input_Frequency : Float)
   is
   begin
      Self.Input_Frequency := Input_Frequency;
      Self.Ratio           := Input_Frequency / Self.Output_Frequency;
   end Set_Input_Frequency;

end Audio.Resamplers;
