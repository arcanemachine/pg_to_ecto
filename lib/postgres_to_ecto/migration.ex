defmodule PostgresToEcto.Migration do
  @moduledoc "Macros for visible, generator-owned Ecto migration regions."

  defmacro __using__(_options) do
    Module.register_attribute(__CALLER__.module, :postgres_to_ecto_key, persist: true)

    quote do
      import PostgresToEcto.Migration, only: [generated_change: 1]
      @doc false
      def __postgres_to_ecto_key__, do: @postgres_to_ecto_key
    end
  end

  defmacro generated_change(do: block), do: block
end
