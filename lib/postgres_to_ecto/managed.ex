defmodule PostgresToEcto.Managed do
  @moduledoc false

  @key_pattern ~r/^[ \t]*@postgres_to_ecto_key[ \t]+"([^"]*)"[ \t]*$/m
  @key_attribute_pattern ~r/^[ \t]*@postgres_to_ecto_key\b/m
  @key_prefix "postgreste1:"
  @digest_bytes 32

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

    @key_prefix <> payload
  end

  @doc false
  def valid_key?(key) when is_binary(key) do
    case key do
      <<@key_prefix, payload::binary>> ->
        case Base.decode64(payload, padding: false) do
          {:ok, digest} -> byte_size(digest) == @digest_bytes
          :error -> false
        end

      _ ->
        false
    end
  end

  def valid_key?(_key), do: false

  def normalize(value) when is_binary(value) do
    case Sourceror.parse_string(value) do
      {:ok, ast} ->
        ast_text =
          ast
          |> Macro.prewalk(fn node -> strip_metadata(node) end)
          |> :erlang.term_to_binary()

        ast_text <> "\ncomments:" <> normalized_comments(value)

      _ ->
        String.trim(value)
    end
  end

  def normalize(value), do: value

  def key_for_source(module, source, region_names) when is_atom(module) and is_binary(source) do
    with {:ok, regions} <- find_regions(source, region_names),
         :ok <- ensure_one_each(regions, region_names) do
      contents =
        Map.new(regions, fn {name, start, finish} ->
          {name, binary_part(source, start, finish - start)}
        end)

      {:ok, key(module, contents)}
    end
  end

  def extract_key(source) when is_binary(source) do
    matches = Regex.scan(@key_pattern, source, capture: :all_but_first)
    attribute_count = length(Regex.scan(@key_attribute_pattern, source))

    case {attribute_count, matches} do
      {1, [[key]]} ->
        if valid_key?(key), do: {:ok, key}, else: {:error, :invalid_key}

      {0, []} ->
        :missing

      _ ->
        {:error, :invalid_key}
    end
  end

  def validate_key(source, expected_key) when is_binary(source) do
    cond do
      not valid_key?(expected_key) ->
        {:error, :invalid_key}

      true ->
        case extract_key(source) do
          {:ok, ^expected_key} -> :ok
          {:ok, _actual} -> {:error, :mismatched_key}
          :missing -> {:error, :missing_key}
          {:error, :invalid_key} -> {:error, :invalid_key}
        end
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
    if not valid_key?(key) do
      {:error, :invalid_key}
    else
      update_key_source(source, key)
    end
  end

  defp update_key_source(source, key) do
    valid_matches = Regex.scan(@key_pattern, source)
    attribute_count = length(Regex.scan(@key_attribute_pattern, source))

    case {length(valid_matches), attribute_count} do
      {1, 1} ->
        {:ok,
         Regex.replace(
           @key_pattern,
           source,
           fn line ->
             Regex.replace(~r/"[^"]*"/, line, "\"#{key}\"", global: false)
           end,
           global: false
         )}

      _ ->
        source = remove_key_attributes(source)
        insert_key_after_ecto_use(source, key)
    end
  end

  defp remove_key_attributes(source) do
    Regex.replace(~r/^[ \t]*@postgres_to_ecto_key[^\n]*\n?/m, source, "")
  end

  defp insert_key_after_ecto_use(source, key) do
    anchors =
      Regex.scan(
        ~r/^[ \t]*use\s+(?:PostgresToEcto\.(?:Schema|Migration)|Ecto\.(?:Schema|Migration)).*$/m,
        source
      )

    case List.last(anchors) do
      [use_line] ->
        indent = Regex.run(~r/^[ \t]*/, use_line) |> List.first()
        key_line = indent <> "@postgres_to_ecto_key \"#{key}\""

        {:ok, String.replace(source, use_line, use_line <> "\n\n" <> key_line, global: false)}

      _ ->
        {:error, :missing_key_anchor}
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
    |> Enum.map_join("\n", fn {line, index} ->
      if index == 0 or String.trim(line) == "", do: line, else: indent <> line
    end)
  end
end
