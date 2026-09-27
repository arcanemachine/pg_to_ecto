defmodule PostgresToEcto.Generator do
  @moduledoc """
  Declarative generator profile configuration.

  A profile records one Repo and the explicitly selected tables. The profile
  contains only literal configuration; generation and database access happen
  outside the profile module.
  """

  @supported_options [:show_generated_key_comment]

  defmacro __using__(options) do
    caller = __CALLER__
    options = literal_keyword!(options, caller, "generator options")

    unknown_options = Keyword.keys(options) -- @supported_options

    if unknown_options != [] do
      raise_compile_error(
        caller,
        "unsupported generator option(s): #{Enum.map_join(unknown_options, ", ", &inspect/1)}"
      )
    end

    show_generated_key_comment = Keyword.get(options, :show_generated_key_comment, true)

    unless is_boolean(show_generated_key_comment) do
      raise_compile_error(caller, "show_generated_key_comment must be a boolean")
    end

    quote do
      Module.register_attribute(__MODULE__, :postgres_to_ecto_generator_options, persist: true)

      Module.register_attribute(__MODULE__, :postgres_to_ecto_repos,
        accumulate: true,
        persist: true
      )

      Module.register_attribute(__MODULE__, :postgres_to_ecto_tables,
        accumulate: true,
        persist: true
      )

      Module.register_attribute(__MODULE__, :postgres_to_ecto_migration_basenames,
        accumulate: true,
        persist: true
      )

      @postgres_to_ecto_generator_options unquote(
                                            Macro.escape(
                                              show_generated_key_comment:
                                                show_generated_key_comment
                                            )
                                          )

      @before_compile PostgresToEcto.Generator
      import PostgresToEcto.Generator, only: [repo: 1, table: 2, table: 3, migration_basename: 1]
    end
  end

  defmacro repo(repo_module) do
    repo_module = Macro.expand(repo_module, __CALLER__)

    quote do
      @postgres_to_ecto_repos unquote(repo_module)
    end
  end

  defmacro migration_basename(basename) do
    caller = __CALLER__
    basename = Macro.expand(basename, caller)

    unless is_binary(basename) do
      raise_compile_error(caller, "migration_basename must be a string")
    end

    quote do
      @postgres_to_ecto_migration_basenames unquote(basename)
    end
  end

  defmacro table(table_name, options) do
    register_table(table_name, options, [], __CALLER__)
  end

  defmacro table(table_name, options, do: block) do
    overrides = parse_overrides(block, __CALLER__)
    register_table(table_name, options, overrides, __CALLER__)
  end

  defmacro __before_compile__(env) do
    repos = Module.get_attribute(env.module, :postgres_to_ecto_repos) |> Enum.reverse()
    tables = Module.get_attribute(env.module, :postgres_to_ecto_tables) |> Enum.reverse()

    migration_basenames =
      Module.get_attribute(env.module, :postgres_to_ecto_migration_basenames) |> Enum.reverse()

    options = Module.get_attribute(env.module, :postgres_to_ecto_generator_options) || []

    profile = %{
      module: env.module,
      options: options,
      repos: repos,
      tables: tables,
      migration_basenames: migration_basenames
    }

    quote do
      @doc false
      def __postgres_to_ecto_profile__, do: unquote(Macro.escape(profile))
    end
  end

  defp register_table(table_name, options, overrides, caller) do
    table_name = Macro.expand(table_name, caller)
    options = literal_keyword!(options, caller, "table options")

    module =
      case Keyword.fetch(options, :module) do
        {:ok, value} -> Macro.expand(value, caller)
        :error -> nil
      end

    file = Keyword.get(options, :file)

    if not is_nil(file) and not is_binary(file) do
      raise_compile_error(caller, "table file must be a string")
    end

    options = options |> Keyword.put(:module, module) |> Keyword.put(:file, file)

    table = %{
      name: table_name,
      module: module,
      file: file,
      options: options,
      overrides: overrides
    }

    quote do
      @postgres_to_ecto_tables unquote(Macro.escape(table))
    end
  end

  defp parse_overrides(block, caller) do
    expressions =
      case block do
        {:__block__, _, expressions} -> expressions
        expression -> [expression]
      end

    Enum.map(expressions, fn
      {:skip_assocs, _, [associations]} ->
        associations = Macro.expand(associations, caller)

        if is_list(associations) and Enum.all?(associations, &is_atom/1) do
          {:skip_assocs, associations}
        else
          raise_compile_error(caller, "skip_assocs must be a literal list of association names")
        end

      {kind, _, [name, type]} when kind in [:field, :belongs_to, :has_one, :has_many] ->
        parse_override(kind, name, type, [], caller)

      {kind, _, [name, type, options]} when kind in [:field, :belongs_to, :has_one, :has_many] ->
        parse_override(
          kind,
          name,
          type,
          literal_keyword!(options, caller, "#{kind} options"),
          caller
        )

      expression ->
        raise_compile_error(
          caller,
          "unsupported table override #{Macro.to_string(expression)}"
        )
    end)
  end

  defp parse_override(kind, name, type, options, caller) do
    name = Macro.expand(name, caller)
    type = Macro.expand(type, caller)

    unless is_atom(name) and not is_nil(name) do
      raise_compile_error(caller, "#{kind} names must be literal atoms")
    end

    if kind == :field and Keyword.has_key?(options, :source) and
         not is_atom(Keyword.get(options, :source)) and
         not is_binary(Keyword.get(options, :source)) do
      raise_compile_error(caller, "field source must be an atom or string")
    end

    %{kind: kind, name: name, type: type, options: options}
  end

  defp literal_keyword!(value, caller, description) do
    value = Macro.expand(value, caller)

    if Keyword.keyword?(value) do
      value
    else
      raise_compile_error(caller, "#{description} must be a literal keyword list")
    end
  end

  defp raise_compile_error(caller, message) do
    raise CompileError, file: caller.file, line: caller.line, description: message
  end
end
