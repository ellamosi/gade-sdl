with Ada.Finalization;

package Audio.IO is

   type Instance is new Ada.Finalization.Limited_Controlled with private;

   procedure Create (Self : aliased out Instance);

   procedure Shutdown (Self : in out Instance);

   generic
      with procedure Generate (Buffer : Audio_Buffer_Access;
                               Count  : out Natural);
   procedure Queue_Asynchronously (Self : in out Instance);

   overriding
   procedure Finalize (Self : in out Instance);

private
   type Instance is new Ada.Finalization.Limited_Controlled with null record;

end Audio.IO;
