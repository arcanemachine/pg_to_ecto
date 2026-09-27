defmodule PostgresToEcto.FileApplication do
  @moduledoc false

  alias PostgresToEcto.{Diagnostic, FileChange}

  @type artifact :: %{path: String.t(), source: String.t()}

  @doc false
  @spec plan([artifact()]) ::
          {:ok, [FileChange.t()]} | {:error, [Diagnostic.t()]}
  def plan(artifacts) when is_list(artifacts) do
    with :ok <- validate_artifacts(artifacts) do
      Enum.reduce_while(artifacts, {:ok, []}, fn artifact, {:ok, changes} ->
        case classify(artifact) do
          {:ok, change} -> {:cont, {:ok, changes ++ [change]}}
          {:error, diagnostic} -> {:halt, {:error, [diagnostic]}}
        end
      end)
    end
  end

  @doc false
  @spec safe_path?(String.t()) :: boolean()
  def safe_path?(path) when is_binary(path), do: not symlink_component?(Path.expand(path))
  def safe_path?(_path), do: false

  @doc false
  @spec write([artifact()], [FileChange.t()]) ::
          :ok | {:error, [Diagnostic.t()]}
  def write(artifacts, changes) when is_list(artifacts) and is_list(changes) do
    artifacts_by_path = Map.new(artifacts, &{&1.path, &1})

    Enum.reduce_while(changes, :ok, fn %{path: path, action: action}, :ok ->
      case action do
        action when action in [:create, :update] ->
          case Map.fetch(artifacts_by_path, path) do
            {:ok, artifact} ->
              case write_atomically(artifact.path, artifact.source) do
                :ok -> {:cont, :ok}
                {:error, reason} -> {:halt, {:error, [write_error(artifact.path, reason)]}}
              end

            :error ->
              {:halt, {:error, [write_error(path, :missing_artifact)]}}
          end

        :unchanged ->
          {:cont, :ok}

        :blocked ->
          {:halt, {:error, [write_error(path, :blocked_file)]}}
      end
    end)
  end

  defp validate_artifacts(artifacts) do
    paths = Enum.map(artifacts, & &1.path)

    cond do
      Enum.any?(artifacts, &(not is_binary(&1.path) or not is_binary(&1.source))) ->
        {:error,
         [
           diagnostic(
             :invalid_file_artifact,
             "Generated file artifacts must contain a path and source string."
           )
         ]}

      length(paths) != length(Enum.uniq(paths)) ->
        {:error,
         [
           diagnostic(
             :duplicate_file_artifact,
             "PostgresToEcto produced more than one artifact for the same file path."
           )
         ]}

      true ->
        :ok
    end
  end

  defp classify(%{path: path, source: source}) do
    if not safe_path?(path) do
      {:error,
       diagnostic(
         :unsafe_file_path,
         "Refusing to update output path #{path} because it contains a symlink."
       )}
    else
      classify_path(path, source)
    end
  end

  defp classify_path(path, source) do
    case File.lstat(path) do
      {:ok, %{type: :symlink}} ->
        {:error,
         diagnostic(:unsafe_file_path, "Refusing to update symlinked output file #{path}.")}

      {:ok, _stat} ->
        case File.read(path) do
          {:ok, ^source} -> {:ok, %FileChange{path: path, action: :unchanged}}
          {:ok, _current} -> {:ok, %FileChange{path: path, action: :update}}
          {:error, reason} -> {:error, read_error(path, reason)}
        end

      {:error, :enoent} ->
        {:ok, %FileChange{path: path, action: :create}}

      {:error, reason} ->
        {:error, read_error(path, reason)}
    end
  end

  defp symlink_component?(path) do
    case File.lstat(path) do
      {:ok, %{type: :symlink}} -> true
      {:ok, _stat} when path in ["/", "."] -> false
      {:ok, _stat} -> symlink_component?(Path.dirname(path))
      {:error, :enoent} when path in ["/", "."] -> false
      {:error, :enoent} -> symlink_component?(Path.dirname(path))
      {:error, _reason} -> true
    end
  end

  defp write_atomically(path, source) do
    directory = Path.dirname(path)
    temporary_path = path <> ".postgres_to_ecto_#{System.unique_integer([:positive])}.tmp"

    with :ok <- File.mkdir_p(directory),
         :ok <- File.write(temporary_path, source, [:binary]),
         :ok <- File.rename(temporary_path, path) do
      :ok
    else
      {:error, reason} ->
        _ = File.rm(temporary_path)
        {:error, reason}
    end
  end

  defp read_error(path, reason),
    do:
      diagnostic(
        :file_read_error,
        "Could not read #{path} before generation: #{inspect(reason)}."
      )

  defp write_error(path, reason),
    do: diagnostic(:file_write_error, "Could not replace #{path}: #{inspect(reason)}.")

  defp diagnostic(code, message), do: %Diagnostic{severity: :error, code: code, message: message}
end
