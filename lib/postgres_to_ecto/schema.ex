defmodule PostgresToEcto.Schema do
  @moduledoc "Macros for visible, generator-owned Ecto schema regions."

  defmacro __using__(_options) do
    Module.register_attribute(__CALLER__.module, :postgres_to_ecto_key, persist: true)

    quote do
      import PostgresToEcto.Schema, only: [generated_settings: 1, generated_fields: 1]
      @doc false
      def __postgres_to_ecto_key__, do: @postgres_to_ecto_key
    end
  end

  defmacro generated_settings(do: block), do: block

  defmacro generated_fields(do: block), do: block

  @doc false
  def render(profile, model, existing_sources \\ %{}, options \\ []) do
    PostgresToEcto.SchemaRenderer.render(profile, model, existing_sources, options)
  end
end
