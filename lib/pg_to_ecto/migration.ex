defmodule PgToEcto.Migration do
  @moduledoc "Macros for visible, generator-owned Ecto migration regions."

  defmacro __using__(_options) do
    Module.register_attribute(__CALLER__.module, :pg_to_ecto_key, persist: true)

    quote do
      import PgToEcto.Migration, only: [generated_change: 1]
      @doc false
      def __pg_to_ecto_key__, do: @pg_to_ecto_key
    end
  end

  defmacro generated_change(do: block), do: block
end
