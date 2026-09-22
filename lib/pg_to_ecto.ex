defmodule PgToEcto do
  @moduledoc """
  Generate Ecto source from an explicitly configured PostgreSQL profile.

  The generator validates a profile, introspects its selected PostgreSQL
  tables, and renders one managed baseline migration.
  """

  @type generation_option :: {:dry_run, boolean()} | {:force, boolean()}

  @spec generate(module(), [generation_option()]) ::
          {:ok, PgToEcto.Result.t()} | {:error, PgToEcto.Result.t()}
  def generate(profile_module, options \\ []) do
    case validate_options(options) do
      {:ok, options} ->
        generate_profile(profile_module, options)

      {:error, diagnostics} ->
        {:error, %PgToEcto.Result{files: [], diagnostics: diagnostics}}
    end
  end

  defp generate_profile(profile_module, options)
       when is_atom(profile_module) and not is_nil(profile_module) do
    try do
      case PgToEcto.Profile.validate(profile_module) do
        {:ok, profile, profile_diagnostics} ->
          generate_baseline(profile, profile_diagnostics, options)

        {:error, diagnostics} ->
          {:error, %PgToEcto.Result{files: [], diagnostics: diagnostics}}
      end
    rescue
      exception ->
        {:error,
         %PgToEcto.Result{
           files: [],
           diagnostics: [
             diagnostic(
               :error,
               :generation_error,
               "PgToEcto could not validate the generator profile: #{Exception.message(exception)}."
             )
           ]
         }}
    catch
      kind, reason ->
        {:error,
         %PgToEcto.Result{
           files: [],
           diagnostics: [
             diagnostic(
               :error,
               :generation_error,
               "PgToEcto could not validate the generator profile (#{kind}: #{inspect(reason)})."
             )
           ]
         }}
    end
  end

  defp generate_profile(_profile_module, _options) do
    {:error,
     %PgToEcto.Result{
       files: [],
       diagnostics: [
         diagnostic(
           :error,
           :invalid_profile,
           "PgToEcto.generate/2 requires an explicit generator profile module."
         )
       ]
     }}
  end

  defp generate_baseline(profile, profile_diagnostics, _options) do
    with {:ok, model} <- PgToEcto.Introspection.introspect_profile(profile),
         {:ok, rendered} <- PgToEcto.Baseline.render(profile, model),
         {:ok, schema_rendered} <-
           PgToEcto.SchemaRenderer.render(profile, model, existing_schema_sources(profile)) do
      {:ok,
       %PgToEcto.Result{
         files: schema_file_changes(schema_rendered.files),
         diagnostics: profile_diagnostics ++ rendered.diagnostics ++ schema_rendered.diagnostics
       }}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error,
         %PgToEcto.Result{
           files: [],
           diagnostics: profile_diagnostics ++ diagnostics
         }}

      {:error, {:repo_unavailable, repo}} ->
        generation_error_result(
          profile_diagnostics,
          :repo_unavailable,
          "The configured Repo #{inspect(repo)} is not running. Start it before generating a baseline migration."
        )

      {:error, {:missing_selected_tables, identities}} ->
        generation_error_result(
          profile_diagnostics,
          :missing_selected_table,
          "PgToEcto could not find selected table(s): #{Enum.map_join(identities, ", ", fn {schema, table} -> schema <> "." <> table end)}."
        )

      {:error, reason} ->
        generation_error_result(
          profile_diagnostics,
          :generation_error,
          "PgToEcto could not generate the baseline migration: #{inspect(reason)}."
        )
    end
  end

  defp existing_schema_sources(profile) do
    Map.new(profile.tables, fn table ->
      case File.read(table.file) do
        {:ok, source} -> {table.file, source}
        {:error, :enoent} -> {table.file, nil}
        {:error, _reason} -> {table.file, nil}
      end
    end)
  end

  defp schema_file_changes(files) do
    Enum.map(files, fn file ->
      action =
        case File.read(file.path) do
          {:ok, source} when source == file.source -> :unchanged
          {:ok, _source} -> :update
          {:error, :enoent} -> :create
          {:error, _reason} -> :blocked
        end

      %PgToEcto.FileChange{path: file.path, action: action}
    end)
  end

  defp generation_error_result(profile_diagnostics, code, message) do
    {:error,
     %PgToEcto.Result{
       files: [],
       diagnostics: profile_diagnostics ++ [diagnostic(:error, code, message)]
     }}
  end

  defp validate_options(options) do
    if is_list(options) and Keyword.keyword?(options) do
      validate_keyword_options(options)
    else
      {:error,
       [
         diagnostic(
           :error,
           :invalid_generation_option,
           "Generation options must be a keyword list."
         )
       ]}
    end
  end

  defp validate_keyword_options(options) do
    unknown_options = Keyword.keys(options) -- [:dry_run, :force]

    cond do
      unknown_options != [] ->
        {:error,
         [
           %PgToEcto.Diagnostic{
             severity: :error,
             code: :invalid_generation_option,
             message:
               "Unsupported generation option(s): #{Enum.map_join(unknown_options, ", ", &inspect/1)}."
           }
         ]}

      not is_boolean(Keyword.get(options, :dry_run, false)) ->
        {:error,
         [
           %PgToEcto.Diagnostic{
             severity: :error,
             code: :invalid_generation_option,
             message: "dry_run must be a boolean."
           }
         ]}

      not is_boolean(Keyword.get(options, :force, false)) ->
        {:error,
         [
           %PgToEcto.Diagnostic{
             severity: :error,
             code: :invalid_generation_option,
             message: "force must be a boolean."
           }
         ]}

      true ->
        {:ok,
         options
         |> Keyword.put_new(:dry_run, false)
         |> Keyword.put_new(:force, false)}
    end
  end

  defp diagnostic(severity, code, message) do
    %PgToEcto.Diagnostic{severity: severity, code: code, message: message}
  end
end
