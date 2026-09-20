defmodule PgToEcto.Managed do
  @moduledoc false

  @key_pattern ~r/@pg_to_ecto_key\s+"(pgte1:[^"]+)"/

  def key(module, regions) when is_atom(module) and is_map(regions) do
    normalized_regions =
      regions
      |> Enum.map(fn {name, source} -> {name, normalize(source)} end)
      |> Enum.sort()

    payload =
      [Atom.to_string(module), normalized_regions]
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode64(padding: false)

    "pgte1:" <> payload
  end

  def normalize(value) when is_binary(value) do
    case Sourceror.parse_string(value) do
      {:ok, ast} ->
        ast_text = ast |> Macro.prewalk(fn node -> strip_metadata(node) end) |> Macro.to_string()
        ast_text <> "\ncomments:" <> normalized_comments(value)

      _ ->
        String.trim(value)
    end
  end

  def normalize(value), do: value

  def key_for_source(module, source, region_names) when is_atom(module) and is_binary(source) do
    with {:ok, regions} <- find_regions(source, region_names) do
      contents =
        Map.new(regions, fn {name, start, finish} ->
          {name, binary_part(source, start, finish - start)}
        end)

      {:ok, key(module, contents)}
    end
  end

  def extract_key(source) when is_binary(source) do
    case Regex.run(@key_pattern, source, capture: :all_but_first) do
      [key] -> {:ok, key}
      nil -> :missing
    end
  end

  def validate_key(source, expected_key) when is_binary(source) do
    case extract_key(source) do
      {:ok, ^expected_key} -> :ok
      {:ok, _actual} -> {:error, :mismatched_key}
      :missing -> {:error, :missing_key}
    end
  end

  def find_regions(source, region_names) when is_binary(source) and is_list(region_names) do
    with {:ok, ast} <- Sourceror.parse_string(source) do
      nodes =
        ast
        |> Macro.prewalk([], fn
          {name, meta, _args} = node, acc when is_list(meta) ->
            if name in region_names, do: {node, [node | acc]}, else: {node, acc}

          node, acc ->
            {node, acc}
        end)
        |> elem(1)

      regions =
        Enum.map(nodes, fn {name, meta, _args} ->
          case {Keyword.get(meta, :line), Keyword.get(meta, :column), Keyword.get(meta, :end)} do
            {line, column, [line: end_line, column: end_column]}
            when is_integer(line) and is_integer(column) ->
              {name, offset(source, line, column), offset(source, end_line, end_column) + 3}

            _ ->
              {name, nil, nil}
          end
        end)

      if Enum.any?(regions, fn {_name, start, finish} -> is_nil(start) or is_nil(finish) end) do
        {:error, :region_range_missing}
      else
        {:ok, Enum.sort_by(regions, &elem(&1, 1))}
      end
    else
      {:error, error} -> {:error, {:parse_error, Exception.message(error)}}
    end
  end

  def patch_regions(source, replacements) when is_binary(source) and is_map(replacements) do
    names = Map.keys(replacements)

    with {:ok, regions} <- find_regions(source, names),
         :ok <- ensure_one_each(regions, names) do
      regions
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.reduce(source, fn {name, start, finish}, current ->
        replacement = Map.fetch!(replacements, name)
        indent = line_indent(current, start)
        replacement = indent_lines(replacement, indent)

        binary_part(current, 0, start) <>
          replacement <> binary_part(current, finish, byte_size(current) - finish)
      end)
      |> parse_result()
    end
  end

  def update_key(source, key) when is_binary(source) and is_binary(key) do
    case Regex.run(@key_pattern, source) do
      [full, old_key] ->
        {:ok, String.replace(source, full, String.replace(full, old_key, key), global: false)}

      nil ->
        case Regex.run(~r/(^\s*use\s+Ecto\.(?:Schema|Migration).*?$)/m, source,
               capture: :all_but_first
             ) do
          [use_line] ->
            {:ok,
             String.replace(source, use_line, use_line <> "\n\n@pg_to_ecto_key \"#{key}\"",
               global: false
             )}

          _ ->
            {:error, :missing_key_anchor}
        end
    end
  end

  defp ensure_one_each(regions, names) do
    if Enum.all?(names, fn name -> Enum.count(regions, &(elem(&1, 0) == name)) == 1 end) do
      :ok
    else
      {:error, :region_count_mismatch}
    end
  end

  defp parse_result(source) do
    case Sourceror.parse_string(source) do
      {:ok, _ast} -> {:ok, source}
      {:error, error} -> {:error, {:parse_error, Exception.message(error)}}
    end
  end

  defp normalized_comments(value) do
    value
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(&1, "#"))
    |> Enum.join("\n")
  end

  defp strip_metadata({name, meta, args}) when is_list(meta), do: {name, [], args}
  defp strip_metadata(node), do: node

  defp offset(source, line, column) do
    source
    |> :binary.split("\n", [:global])
    |> Enum.take(line - 1)
    |> Enum.map(&byte_size/1)
    |> Enum.sum()
    |> Kernel.+(max(line - 1, 0))
    |> Kernel.+(column - 1)
  end

  defp line_indent(source, offset) do
    source
    |> binary_part(0, offset)
    |> String.split("\n")
    |> List.last()
    |> then(&(Regex.run(~r/^\s*/, &1) |> List.first()))
  end

  defp indent_lines(text, indent) do
    text
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {line, index} -> if index == 0, do: line, else: indent <> line end)
  end
end
