defmodule PgToEcto do
  @moduledoc """
  Generate Ecto source from an explicitly configured PostgreSQL profile.

  The profile and public result spine are available before database
  introspection and renderers are added.
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
        {:ok, _profile, diagnostics} ->
          _dry_run = Keyword.fetch!(options, :dry_run)
          _force = Keyword.fetch!(options, :force)
          {:ok, %PgToEcto.Result{files: [], diagnostics: diagnostics}}

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
