defmodule PgToEcto.Profile do
  @moduledoc false

  @default_migration_filename "00001_pg_to_ecto.exs"
  @default_migration_path "priv/repo/migrations"
  @migration_filename ~r/^([0-9]+)_([a-z0-9]+(?:_[a-z0-9]+)*)\.exs$/

  @spec validate(module()) ::
          {:ok, map(), [PgToEcto.Diagnostic.t()]} | {:error, [PgToEcto.Diagnostic.t()]}
  def validate(profile_module) do
    with {:ok, raw_profile} <- load(profile_module) do
      validate_profile(raw_profile)
    end
  end

  @spec load(module() | nil) :: {:ok, map()} | {:error, [PgToEcto.Diagnostic.t()]}
  def load(nil) do
    case Application.get_env(:pg_to_ecto, :generator) do
      nil ->
        {:error,
         [
           diagnostic(
             :error,
             :missing_profile,
             "No PgToEcto generator profile is configured. Add " <>
               "config :pg_to_ecto, generator: MyApp.PgToEcto."
           )
         ]}

      profile_module ->
        load(profile_module)
    end
  end

  def load(profile_module) when is_atom(profile_module) do
    with {:module, _module} <- Code.ensure_loaded(profile_module),
         true <- function_exported?(profile_module, :__pg_to_ecto_profile__, 0) do
      {:ok, profile_module.__pg_to_ecto_profile__()}
    else
      false ->
        {:error,
         [
           diagnostic(
             :error,
             :invalid_profile,
             "#{inspect(profile_module)} is not a PgToEcto generator profile. " <>
               "Use `use PgToEcto.Generator` in the profile module."
           )
         ]}

      {:error, _reason} ->
        {:error,
         [
           diagnostic(
             :error,
             :invalid_profile,
             "PgToEcto generator profile #{inspect(profile_module)} could not be loaded."
           )
         ]}
    end
  end

  def load(_profile_module) do
    {:error, [diagnostic(:error, :invalid_profile, "Generator profile must be a module name.")]}
  end

  @doc false
  def normalize_table_name(name, prefix \\ "public")

  def normalize_table_name(name, prefix) when is_binary(name) do
    if String.contains?(name, <<0>>) do
      {:error, :invalid_table_name}
    else
      case split_qualified_identifier(name) do
        {:ok, [table]} ->
          if nonempty_identifier?(prefix) do
            {:ok, %{schema: prefix, table: table}}
          else
            {:error, :invalid_table_prefix}
          end

        {:ok, [schema, table]} ->
          {:ok, %{schema: schema, table: table}}

        _ ->
          {:error, :invalid_table_name}
      end
    end
  end

  def normalize_table_name(_name, _prefix), do: {:error, :invalid_table_name}

  @doc false
  def default_file_path(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.trim_leading("Elixir.")
    |> String.split(".")
    |> Enum.map(&snake_case/1)
    |> Path.join()
    |> then(&Path.join("lib", &1 <> ".ex"))
  end

  @doc false
  def migration_filename, do: @default_migration_filename

  defp validate_profile(raw_profile) when is_map(raw_profile) do
    options = Map.get(raw_profile, :options, [])
    repositories = Map.get(raw_profile, :repos, [])
    tables = Map.get(raw_profile, :tables, [])
    migration_basenames = Map.get(raw_profile, :migration_basenames, [])

    {diagnostics, options} = validate_options(options, [])
    {diagnostics, repo} = validate_repo(repositories, diagnostics)

    {diagnostics, repo_config} =
      case repo_config(repo) do
        {:ok, repo_config} -> {diagnostics, repo_config}
        {:error, repo_diagnostic} -> {diagnostics ++ [repo_diagnostic], []}
      end

    prefix = Keyword.get(repo_config, :migration_default_prefix) || "public"
    migration_path = migration_path(repo, repo_config)

    {diagnostics, normalized_tables} =
      validate_tables(tables, prefix, diagnostics)

    {diagnostics, migration_filename} =
      validate_migration_filename(migration_basenames, diagnostics)

    {diagnostics, migration_path} =
      validate_migration_path(migration_path, diagnostics)

    {diagnostics, migration_conflicts} =
      validate_migration_conflicts(migration_path, migration_filename, diagnostics)

    diagnostics = diagnostics ++ migration_conflicts

    if has_errors?(diagnostics) do
      {:error, diagnostics}
    else
      {:ok,
       %{
         module: Map.get(raw_profile, :module),
         options: options,
         repo: repo,
         tables: normalized_tables,
         migration_filename: migration_filename,
         migration_path: migration_path,
         migration_file: Path.join(migration_path, migration_filename),
         migration_default_prefix: prefix
       }, diagnostics}
    end
  end

  defp validate_profile(_raw_profile) do
    {:error,
     [
       diagnostic(
         :error,
         :invalid_profile,
         "The generator profile returned invalid configuration."
       )
     ]}
  end

  defp validate_options(options, diagnostics) do
    if is_list(options) and Keyword.keyword?(options) do
      validate_keyword_options(options, diagnostics)
    else
      {
        diagnostics ++
          [
            diagnostic(
              :error,
              :invalid_generator_option,
              "Generator options must be a keyword list."
            )
          ],
        []
      }
    end
  end

  defp validate_keyword_options(options, diagnostics) do
    show_generated_key_comment = Keyword.get(options, :show_generated_key_comment, true)

    diagnostics =
      if is_boolean(show_generated_key_comment) do
        diagnostics
      else
        diagnostics ++
          [
            diagnostic(
              :error,
              :invalid_generator_option,
              "show_generated_key_comment must be a boolean."
            )
          ]
      end

    {diagnostics, Keyword.put(options, :show_generated_key_comment, show_generated_key_comment)}
  end

  defp validate_repo([], diagnostics) do
    {diagnostics ++
       [
         diagnostic(
           :error,
           :missing_repo,
           "The generator profile must declare one Repo with `repo MyApp.Repo`."
         )
       ], nil}
  end

  defp validate_repo([repo], diagnostics) when is_atom(repo) and not is_nil(repo) do
    if module_name?(repo) do
      {diagnostics, repo}
    else
      {
        diagnostics ++
          [diagnostic(:error, :invalid_repo, "The generator profile Repo must be a module name.")],
        nil
      }
    end
  end

  defp validate_repo(repositories, diagnostics) when length(repositories) > 1 do
    {diagnostics ++
       [
         diagnostic(
           :error,
           :duplicate_repo_declaration,
           "The generator profile must declare exactly one Repo."
         )
       ], nil}
  end

  defp validate_repo(_repositories, diagnostics) do
    {diagnostics ++
       [diagnostic(:error, :invalid_repo, "The generator profile Repo must be a module name.")],
     nil}
  end

  defp validate_tables([], _prefix, diagnostics) do
    {
      diagnostics ++
        [
          diagnostic(
            :error,
            :missing_tables,
            "The generator profile must select at least one table."
          )
        ],
      []
    }
  end

  defp validate_tables(tables, prefix, diagnostics) when is_list(tables) do
    {diagnostics, normalized_tables, _seen_names, _seen_modules} =
      Enum.reduce(tables, {diagnostics, [], %{}, %{}}, fn table,
                                                          {diagnostics, normalized, seen_names,
                                                           seen_modules} ->
        {diagnostics, normalized_table} = validate_table(table, prefix, diagnostics)

        if normalized_table do
          identity = {normalized_table.schema, normalized_table.table}
          module = normalized_table.module
          name_duplicate? = Map.has_key?(seen_names, identity)
          module_duplicate? = module_name?(module) and Map.has_key?(seen_modules, module)

          diagnostics =
            if name_duplicate? do
              diagnostics ++
                [
                  diagnostic(
                    :error,
                    :duplicate_table_declaration,
                    "The table #{format_identity(identity)} is declared more than once."
                  )
                ]
            else
              diagnostics
            end

          diagnostics =
            if module_duplicate? do
              diagnostics ++
                [
                  diagnostic(
                    :error,
                    :duplicate_module_declaration,
                    "The Ecto module #{inspect(module)} is assigned to more than one table."
                  )
                ]
            else
              diagnostics
            end

          {
            diagnostics,
            normalized ++ [normalized_table],
            Map.put(seen_names, identity, true),
            if(module_name?(module), do: Map.put(seen_modules, module, true), else: seen_modules)
          }
        else
          {diagnostics, normalized, seen_names, seen_modules}
        end
      end)

    {diagnostics, normalized_tables}
  end

  defp validate_tables(_tables, _prefix, diagnostics) do
    {
      diagnostics ++
        [diagnostic(:error, :invalid_table_selection, "Selected tables must be a list.")],
      []
    }
  end

  defp validate_table(table, prefix, diagnostics) when is_map(table) do
    name = Map.get(table, :name)
    module = Map.get(table, :module)
    file = Map.get(table, :file)
    options = Map.get(table, :options, [])

    diagnostics = validate_table_options(options, diagnostics)

    {diagnostics, identity} =
      case normalize_table_name(name, prefix) do
        {:ok, identity} ->
          {diagnostics, identity}

        {:error, :invalid_table_name} ->
          {
            diagnostics ++
              [
                diagnostic(
                  :error,
                  :invalid_table_name,
                  "Table name #{inspect(name)} must be a nonempty name or schema-qualified name."
                )
              ],
            nil
          }

        {:error, :invalid_table_prefix} ->
          {
            diagnostics ++
              [
                diagnostic(
                  :error,
                  :invalid_table_prefix,
                  "An unqualified table name requires a nonempty Repo migration_default_prefix."
                )
              ],
            nil
          }
      end

    {diagnostics, module} =
      cond do
        is_nil(module) ->
          {
            diagnostics ++
              [
                diagnostic(
                  :error,
                  :missing_table_module,
                  "Every selected table must declare an Ecto module with `module: MyApp.Table`."
                )
              ],
            nil
          }

        module_name?(module) ->
          {diagnostics, module}

        true ->
          {
            diagnostics ++
              [
                diagnostic(
                  :error,
                  :invalid_table_module,
                  "The Ecto module for #{inspect(name)} must be a module name."
                )
              ],
            nil
          }
      end

    {diagnostics, file} =
      case file do
        nil ->
          {diagnostics, if(module_name?(module), do: default_file_path(module), else: nil)}

        value when is_binary(value) ->
          validate_output_path(value, diagnostics, :schema)

        _ ->
          {
            diagnostics ++
              [diagnostic(:error, :invalid_output_path, "Schema output paths must be strings.")],
            nil
          }
      end

    if identity && module do
      {diagnostics,
       Map.merge(identity, %{
         module: module,
         file: file,
         source_name: name
       })}
    else
      {diagnostics, nil}
    end
  end

  defp validate_table(_table, _prefix, diagnostics) do
    {diagnostics ++
       [diagnostic(:error, :invalid_table, "The profile contains an invalid table declaration.")],
     nil}
  end

  defp validate_table_options(options, diagnostics) when is_list(options) do
    if not Keyword.keyword?(options) do
      diagnostics ++
        [diagnostic(:error, :invalid_table_option, "Table options must be a keyword list.")]
    else
      unknown_options = Keyword.keys(options) -- [:module, :file]

      if unknown_options == [] do
        diagnostics
      else
        diagnostics ++
          [
            diagnostic(
              :error,
              :invalid_table_option,
              "Unsupported table option(s): #{Enum.map_join(unknown_options, ", ", &inspect/1)}."
            )
          ]
      end
    end
  end

  defp validate_table_options(_options, diagnostics) do
    diagnostics ++
      [diagnostic(:error, :invalid_table_option, "Table options must be a keyword list.")]
  end

  defp validate_migration_filename([], diagnostics),
    do: validate_migration_filename([@default_migration_filename], diagnostics)

  defp validate_migration_filename([filename], diagnostics) when is_binary(filename) do
    case Regex.run(@migration_filename, filename, capture: :all_but_first) do
      [_version, _name] ->
        {diagnostics, filename}

      _ ->
        {
          diagnostics ++
            [
              diagnostic(
                :error,
                :invalid_migration_filename,
                "Migration filename #{inspect(filename)} must match NNNNN_name.exs without directory components."
              )
            ],
          @default_migration_filename
        }
    end
  end

  defp validate_migration_filename(_filenames, diagnostics) do
    {
      diagnostics ++
        [
          diagnostic(
            :error,
            :duplicate_migration_filename,
            "The generator profile may configure only one migration filename."
          )
        ],
      @default_migration_filename
    }
  end

  defp validate_migration_path(path, diagnostics) when is_binary(path) do
    validate_output_path(path, diagnostics, :migration_directory)
  end

  defp validate_migration_path(_path, diagnostics) do
    {
      diagnostics ++
        [
          diagnostic(
            :error,
            :invalid_output_path,
            "The migration directory must be a relative path."
          )
        ],
      @default_migration_path
    }
  end

  defp validate_migration_conflicts(path, filename, diagnostics) do
    if has_errors?(diagnostics) do
      {diagnostics, []}
    else
      version = migration_version(filename)
      directory = Path.expand(path, project_root())

      case File.ls(directory) do
        {:ok, entries} ->
          conflicts =
            entries
            |> Enum.filter(&migration_file?/1)
            |> Enum.filter(fn entry ->
              migration_version(entry) == version and entry != filename
            end)
            |> Enum.sort()

          if conflicts == [] do
            {diagnostics, []}
          else
            {
              diagnostics,
              [
                diagnostic(
                  :error,
                  :migration_version_conflict,
                  "Migration version #{version} is already used by #{Enum.join(conflicts, ", ")}. " <>
                    "Choose a different migration filename."
                )
              ]
            }
          end

        {:error, :enoent} ->
          {diagnostics, []}

        {:error, reason} ->
          {
            diagnostics,
            [
              diagnostic(
                :error,
                :migration_directory_unreadable,
                "Migration directory #{path} could not be inspected: #{inspect(reason)}."
              )
            ]
          }
      end
    end
  end

  defp validate_output_path(path, diagnostics, kind) when is_binary(path) do
    invalid? =
      path == "" or
        Path.type(path) == :absolute or
        String.contains?(path, "\\") or
        Enum.any?(Path.split(path), &(&1 == "..")) or
        Path.expand(path, project_root()) |> outside_project?()

    if invalid? do
      {
        diagnostics ++
          [
            diagnostic(
              :error,
              :invalid_output_path,
              "#{String.capitalize(to_string(kind))} output path #{inspect(path)} must stay inside the Mix project."
            )
          ],
        nil
      }
    else
      {diagnostics, path}
    end
  end

  defp repo_config(nil), do: {:ok, []}

  defp repo_config(repo) when is_atom(repo) do
    case Code.ensure_loaded(repo) do
      {:module, _module} ->
        if function_exported?(repo, :config, 0) do
          try do
            config = repo.config()

            if Keyword.keyword?(config) do
              {:ok, config}
            else
              {
                :error,
                diagnostic(
                  :error,
                  :invalid_repo_config,
                  "Repo #{inspect(repo)} config/0 must return a keyword list."
                )
              }
            end
          rescue
            exception ->
              {
                :error,
                diagnostic(
                  :error,
                  :repo_config_error,
                  "Repo #{inspect(repo)} config/0 failed: #{Exception.message(exception)}."
                )
              }
          catch
            kind, reason ->
              {
                :error,
                diagnostic(
                  :error,
                  :repo_config_error,
                  "Repo #{inspect(repo)} config/0 failed with #{kind}: #{inspect(reason)}."
                )
              }
          end
        else
          {
            :error,
            diagnostic(
              :error,
              :repo_config_unavailable,
              "Repo #{inspect(repo)} must export config/0 for PgToEcto migration settings."
            )
          }
        end

      {:error, reason} ->
        {
          :error,
          diagnostic(
            :error,
            :repo_config_unavailable,
            "Repo #{inspect(repo)} could not be loaded: #{inspect(reason)}."
          )
        }
    end
  end

  defp repo_config(_repo) do
    {:error,
     diagnostic(:error, :repo_config_unavailable, "The configured Repo must be a module name.")}
  end

  defp migration_path(repo, repo_config) do
    case Keyword.get(repo_config, :priv) do
      nil -> Path.join(["priv", repo_directory(repo), "migrations"])
      priv when is_binary(priv) -> Path.join(priv, "migrations")
      _ -> nil
    end
  end

  defp repo_directory(repo) when is_atom(repo) and not is_nil(repo) do
    repo
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp repo_directory(_repo), do: "repo"

  defp migration_file?(entry) do
    Regex.match?(~r/^[0-9]+_[^\/]+\.exs$/, entry)
  end

  defp migration_version(filename) do
    case Regex.run(~r/^([0-9]+)_/, filename, capture: :all_but_first) do
      [version] -> String.to_integer(version)
      _ -> nil
    end
  end

  defp split_qualified_identifier(value) do
    value
    |> String.graphemes()
    |> split_identifier_characters([], [], :unquoted)
  end

  defp split_identifier_characters([], _current, _parts, :quoted), do: {:error, :unclosed_quote}

  defp split_identifier_characters([], current, parts, state) do
    with {:ok, part} <- finish_identifier_part(current, state) do
      {:ok, Enum.reverse([part | parts])}
    end
  end

  defp split_identifier_characters(["\"" | rest], current, parts, :unquoted) do
    if current == [] do
      split_identifier_characters(rest, current, parts, :quoted)
    else
      {:error, :malformed_quote}
    end
  end

  defp split_identifier_characters(["\"" | ["\"" | rest]], current, parts, :quoted) do
    split_identifier_characters(rest, ["\"" | current], parts, :quoted)
  end

  defp split_identifier_characters(["\"" | rest], current, parts, :quoted) do
    split_identifier_characters(rest, current, parts, :closed)
  end

  defp split_identifier_characters(["." | rest], current, parts, state)
       when state in [:unquoted, :closed] do
    with {:ok, part} <- finish_identifier_part(current, state) do
      split_identifier_characters(rest, [], [part | parts], :unquoted)
    end
  end

  defp split_identifier_characters(_rest, _current, _parts, :closed),
    do: {:error, :malformed_quote}

  defp split_identifier_characters([character | rest], current, parts, state) do
    split_identifier_characters(rest, [character | current], parts, state)
  end

  defp finish_identifier_part([], _state), do: {:error, :empty_identifier}

  defp finish_identifier_part(characters, _state) do
    {:ok, characters |> Enum.reverse() |> Enum.join()}
  end

  defp nonempty_identifier?(value) do
    is_binary(value) and value != "" and not String.contains?(value, <<0>>)
  end

  defp module_name?(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> String.starts_with?("Elixir.")
  end

  defp module_name?(_value), do: false

  defp format_identity({schema, table}), do: "#{schema}.#{table}"

  defp has_errors?(diagnostics), do: Enum.any?(diagnostics, &(&1.severity == :error))

  defp diagnostic(severity, code, message) do
    %PgToEcto.Diagnostic{severity: severity, code: code, message: message}
  end

  defp project_root do
    try do
      Mix.Project.project_file() |> Path.dirname()
    rescue
      _ -> File.cwd!()
    end
  end

  defp outside_project?(path) do
    root = Path.expand(project_root())
    expanded = Path.expand(path)
    expanded != root and not String.starts_with?(expanded, root <> "/")
  end

  defp snake_case(value) do
    value
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end
end
