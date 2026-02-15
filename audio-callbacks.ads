private package Audio.Callbacks is
   use Devices;

   type Callback_Context is tagged limited private;

   type Callback_Context_Access is access all Callback_Context;

   function Create
     (Ring : Ring_Buffer_Access)
      return Callback_Context_Access;

   procedure Set_Spec
     (Context : in out Callback_Context;
      Spec    : Obtained_Spec);

   function User_Data (Context : aliased in out Callback_Context)
                       return User_Data_Access;

   function Callback (Context : aliased in out Callback_Context)
                      return Audio_Callback;

   function Level (Context : Callback_Context) return Float;

   function Output_Frequency (Context : Callback_Context) return Positive;

private
   Default_Output_Frequency : constant Positive := 48_000;

   type Callback_Context is limited new Devices.User_Data with record
      Ring_Bis : Ring_Buffer_Access;
      Margin_Frames    : Positive := 1;
      Margin_Low       : Natural := 0;
      Margin_High      : Positive := 1;
      Output_Frequency : Positive := Default_Output_Frequency;
   end record;

   procedure SDL_Callback
     (User_Data : User_Data_Access;
      Buffer    : out Bounded_Float_Buffers.Data_Container);

   procedure Write_Silence (Buffer : out Bounded_Float_Buffers.Data_Container);

end Audio.Callbacks;
