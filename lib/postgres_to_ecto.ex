defmodule PostgresToEcto do
  @moduledoc """
  Generate Ecto source from an explicitly configured PostgreSQL profile.

  The generator validates a profile, introspects its selected PostgreSQL
  tables, and renders one managed baseline migration.
  """

  @type generation_option :: {:dry_run, boolean()} | {:force, boolean()}

  @spec generate(module(), [generation_option()]) ::
          {:ok, PostgresToEcto.Result.t()} | {:error, PostgresToEcto.Result.t()}
  def generate(profile_module, options \\ []) do
    case validate_options(options) do
      {:ok, options} ->
        generate_profile(profile_module, options)

      {:error, diagnostics} ->
        {:error, %PostgresToEcto.Result{files: [], diagnostics: diagnostics}}
    end
  end

  defp generate_profile(profile_module, options)
       when is_atom(profile_module) and not is_nil(profile_module) do
    try do
      case PostgresToEcto.Profile.validate(profile_module) do
        {:ok, profile, profile_diagnostics} ->
          generate_baseline(profile, profile_diagnostics, options)

        {:error, diagnostics} ->
          {:error, %PostgresToEcto.Result{files: [], diagnostics: diagnostics}}
      end
    rescue
      exception ->
        {:error,
         %PostgresToEcto.Result{
           files: [],
           diagnostics: [
             diagnostic(
               :error,
               :generation_error,
               "PostgresToEcto could not validate the generator profile: #{Exception.message(exception)}."
             )
           ]
         }}
    catch
      kind, reason ->
        {:error,
         %PostgresToEcto.Result{
           files: [],
           diagnostics: [
             diagnostic(
               :error,
               :generation_error,
               "PostgresToEcto could not validate the generator profile (#{kind}: #{inspect(reason)})."
             )
           ]
         }}
    end
  end

  defp generate_profile(_profile_module, _options) do
    {:error,
     %PostgresToEcto.Result{
       files: [],
       diagnostics: [
         diagnostic(
           :error,
           :invalid_profile,
           "PostgresToEcto.generate/2 requires an explicit generator profile module."
         )
       ]
     }}
  end

  defp generate_baseline(profile, profile_diagnostics, options) do
    with {:ok, model} <- PostgresToEcto.Introspection.introspect_profile(profile),
         {:ok, existing_sources} <- read_existing_sources(profile),
         {:ok, artifacts, render_diagnostics} <-
           render_outputs(profile, model, existing_sources, options),
         {:ok, file_changes} <- PostgresToEcto.FileApplication.plan(artifacts) do
      result = %PostgresToEcto.Result{
        files: file_changes,
        diagnostics: profile_diagnostics ++ render_diagnostics
      }

      if Keyword.get(options, :dry_run, false) do
        {:ok, result}
      else
        case PostgresToEcto.FileApplication.write(artifacts, file_changes) do
          :ok ->
            {:ok, result}

          {:error, diagnostics} ->
            {:error, %{result | diagnostics: result.diagnostics ++ diagnostics}}
        end
      end
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error,
         %PostgresToEcto.Result{files: [], diagnostics: profile_diagnostics ++ diagnostics}}

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
          "PostgresToEcto could not find selected table(s): #{Enum.map_join(identities, ", ", fn {schema, table} -> schema <> "." <> table end)}."
        )

      {:error, reason} ->
        generation_error_result(
          profile_diagnostics,
          :generation_error,
          "PostgresToEcto could not generate the baseline migration: #{inspect(reason)}."
        )
    end
  end

  defp read_existing_sources(profile) do
    paths = Enum.map(profile.tables, & &1.file) ++ [profile.migration_file]

    Enum.reduce_while(paths, {:ok, %{}}, fn path, {:ok, sources} ->
      case read_existing_source(path) do
        {:ok, source} -> {:cont, {:ok, Map.put(sources, path, source)}}
        {:error, diagnostic} -> {:halt, {:error, [diagnostic]}}
      end
    end)
  end

  defp read_existing_source(path) do
    if not PostgresToEcto.FileApplication.safe_path?(path) do
      {:error,
       diagnostic(
         :error,
         :unsafe_file_path,
         "Refusing to read output path #{path} because it contains a symlink."
       )}
    else
      read_existing_file(path)
    end
  end

  defp read_existing_file(path) do
    case File.lstat(path) do
      {:ok, %{type: :symlink}} ->
        {:error,
         diagnostic(
           :error,
           :unsafe_file_path,
           "Refusing to read symlinked output file #{path}."
         )}

      {:ok, _stat} ->
        case File.read(path) do
          {:ok, source} ->
            {:ok, source}

          {:error, reason} ->
            {:error,
             diagnostic(:error, :file_read_error, "Could not read #{path}: #{inspect(reason)}.")}
        end

      {:error, :enoent} ->
        {:ok, nil}

      {:error, reason} ->
        {:error,
         diagnostic(:error, :file_read_error, "Could not inspect #{path}: #{inspect(reason)}.")}
    end
  end

  defp render_outputs(profile, model, existing_sources, options) do
    force_options = [force: Keyword.get(options, :force, false)]
    existing_migration_source = Map.get(existing_sources, profile.migration_file)

    baseline_result =
      PostgresToEcto.Baseline.render(profile, model, existing_migration_source, force_options)

    schema_result =
      PostgresToEcto.SchemaRenderer.render(profile, model, existing_sources, force_options)

    case {baseline_result, schema_result} do
      {{:ok, baseline}, {:ok, schemas}} ->
        artifacts = schemas.files ++ [%{path: profile.migration_file, source: baseline.source}]
        diagnostics = baseline.diagnostics ++ schemas.diagnostics
        {:ok, artifacts, diagnostics}

      _ ->
        {:error, render_diagnostics(baseline_result, schema_result)}
    end
  end

  defp render_diagnostics(baseline_result, schema_result) do
    [baseline_result, schema_result]
    |> Enum.flat_map(fn
      {:ok, rendered} -> Map.get(rendered, :diagnostics, [])
      {:error, diagnostics} -> diagnostics
    end)
  end

  defp generation_error_result(profile_diagnostics, code, message) do
    {:error,
     %PostgresToEcto.Result{
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
           %PostgresToEcto.Diagnostic{
             severity: :error,
             code: :invalid_generation_option,
             message:
               "Unsupported generation option(s): #{Enum.map_join(unknown_options, ", ", &inspect/1)}."
           }
         ]}

      not is_boolean(Keyword.get(options, :dry_run, false)) ->
        {:error,
         [
           %PostgresToEcto.Diagnostic{
             severity: :error,
             code: :invalid_generation_option,
             message: "dry_run must be a boolean."
           }
         ]}

      not is_boolean(Keyword.get(options, :force, false)) ->
        {:error,
         [
           %PostgresToEcto.Diagnostic{
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
    %PostgresToEcto.Diagnostic{severity: severity, code: code, message: message}
  end
end
