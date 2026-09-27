defmodule PostgresToEcto.SchemaRenderer do
  @moduledoc false

  alias PostgresToEcto.{Diagnostic, Managed}

  @association_calls [:belongs_to, :has_one, :has_many, :many_to_many]
  @field_calls [:field | @association_calls]

  @type artifact :: %{
          module: module(),
          path: String.t(),
          source: String.t(),
          key: String.t()
        }

  @type render_result :: %{files: [artifact()], diagnostics: [Diagnostic.t()]}

  @doc false
  @spec render(map(), map(), map(), keyword()) ::
          {:ok, render_result()} | {:error, [Diagnostic.t()]}
  def render(profile, model, existing_sources \\ %{}, options \\ [])
      when is_map(profile) and is_map(model) and is_map(existing_sources) and is_list(options) do
    tables = Map.get(model, :tables, [])
    table_by_identity = Map.new(tables, &{table_identity(&1), &1})

    {artifacts, diagnostics} =
      Enum.reduce(tables, {[], []}, fn table, {artifacts, diagnostics} ->
        case render_table(profile, table, table_by_identity, existing_sources, options) do
          {:ok, artifact, table_diagnostics} ->
            {artifacts ++ [artifact], diagnostics ++ table_diagnostics}

          {:error, table_diagnostics} ->
            {artifacts, diagnostics ++ table_diagnostics}
        end
      end)

    if has_errors?(diagnostics) do
      {:error, diagnostics}
    else
      {:ok, %{files: artifacts, diagnostics: diagnostics}}
    end
  end

  @doc false
  @spec render_one(map(), map(), map(), map(), keyword()) ::
          {:ok, artifact(), [Diagnostic.t()]} | {:error, [Diagnostic.t()]}
  def render_one(profile, table, tables, existing_sources \\ %{}, options \\ []) do
    render_table(profile, table, tables, existing_sources, options)
  end

  defp render_table(profile, table, table_by_identity, existing_sources, options) do
    module = table_module(table)
    path = table_path(table)
    columns = Map.get(table, :columns, [])
    overrides = table_overrides(table)
    field_overrides = overrides |> Enum.filter(&match?(%{kind: :field}, &1))

    association_overrides =
      overrides
      |> Enum.filter(&match?(%{kind: kind} when kind in [:belongs_to, :has_one, :has_many], &1))

    skip_assocs =
      overrides
      |> Enum.flat_map(fn
        {:skip_assocs, names} -> names
        _ -> []
      end)
      |> MapSet.new()

    {field_specs, field_diagnostics, field_names_by_source} =
      render_fields(table, columns, field_overrides)

    {associations, association_diagnostics} =
      render_associations(
        table,
        table_by_identity,
        field_names_by_source,
        association_overrides,
        skip_assocs
      )

    diagnostics =
      field_diagnostics ++
        association_diagnostics ++
        unselected_reference_diagnostics(table)

    settings = render_settings(table, columns)
    regions = region_map(settings, field_specs ++ associations)
    region_names = Map.keys(regions) |> Enum.sort()

    with false <- has_errors?(diagnostics),
         {:ok, source, key, source_diagnostics} <-
           render_source(
             profile,
             module,
             table,
             regions,
             region_names,
             Map.get(existing_sources, path) || Map.get(existing_sources, module),
             options
           ) do
      {:ok, %{module: module, path: path, source: source, key: key},
       diagnostics ++ source_diagnostics}
    else
      true -> {:error, diagnostics}
      {:error, source_diagnostics} -> {:error, diagnostics ++ source_diagnostics}
    end
  end

  defp render_fields(table, columns, overrides) do
    overrides_by_source =
      Map.new(overrides, fn override ->
        source = Keyword.get(override.options, :source, override.name)
        {to_string(source), override}
      end)

    {specs, diagnostics, names} =
      Enum.reduce(columns, {[], [], %{}}, fn column, {specs, diagnostics, names} ->
        if implicit_primary_key?(table, column) do
          {specs, diagnostics, Map.put(names, column.name, :id)}
        else
          source = column.name
          override = Map.get(overrides_by_source, source)

          case render_field(column, override, table, names) do
            {:ok, spec, field_name, field_diagnostics} ->
              {specs ++ [spec], diagnostics ++ field_diagnostics,
               Map.put(names, source, field_name)}

            {:skip, field_diagnostics} ->
              {specs, diagnostics ++ field_diagnostics, names}
          end
        end
      end)

    unknown_overrides =
      Enum.reject(overrides, fn override ->
        source = Keyword.get(override.options, :source, override.name)

        Map.has_key?(names, to_string(source)) or
          Enum.any?(columns, &(&1.name == to_string(source)))
      end)

    unknown_diagnostics =
      Enum.map(unknown_overrides, fn override ->
        warning(
          :unknown_field_override,
          "#{inspect(table_module(table))} field override #{inspect(override.name)} does not name a column in #{identity_text(table.identity)}."
        )
      end)

    {specs, diagnostics ++ unknown_diagnostics, names}
  end

  defp render_field(column, override, table, names) do
    source = column.name
    field_name = if override, do: override.name, else: field_name(source)

    cond do
      Map.has_key?(names, source) ->
        {:skip,
         [
           error(
             :generated_field_collision,
             "#{identity_text(table.identity)} maps more than one field to #{inspect(field_name)}."
           )
         ]}

      is_nil(column_type(column)) and is_nil(override) ->
        {:skip,
         [
           warning(
             :unmapped_schema_field,
             "#{identity_text(table.identity)}.#{source} has no safe Ecto schema type. Add a field override such as `field #{inspect(field_name)}, MyApp.Type, source: #{inspect(source)}`."
           )
         ]}

      true ->
        type = if override, do: override.type, else: column_type(column)
        options = field_options(column, override, table, field_name)
        spec = {:field, field_name, type, options}
        diagnostics = unusual_identifier_diagnostics(table, source, field_name, override)
        {:ok, spec, field_name, diagnostics}
    end
  end

  defp field_options(column, override, table, field_name) do
    primary_key? =
      Map.get(column, :primary_key?, false) or column.name in Map.get(table, :primary_key, [])

    implicit_primary_key? = implicit_primary_key?(table, column)

    options =
      []
      |> maybe_put(:primary_key, primary_key? and not implicit_primary_key?, false)
      |> maybe_put(:default, safe_default(column), nil)
      |> maybe_put(:read_after_writes, database_default?(column), false)

    override_options = if override, do: override.options, else: []

    override_options =
      if Keyword.has_key?(override_options, :source) do
        Keyword.update!(override_options, :source, fn
          source when is_binary(source) -> String.to_atom(source)
          source -> source
        end)
      else
        override_options
      end

    options =
      if Keyword.has_key?(override_options, :source) or Atom.to_string(field_name) == column.name do
        options
      else
        Keyword.put(options, :source, String.to_atom(column.name))
      end

    Keyword.merge(options, override_options)
  end

  defp render_associations(table, table_by_identity, field_names, overrides, skip_assocs) do
    automatic = automatic_associations(table, table_by_identity, field_names)

    automatic =
      Enum.reject(automatic, fn {_kind, name, _module, _options, _source} ->
        MapSet.member?(skip_assocs, name)
      end)

    explicit =
      Enum.map(overrides, fn override ->
        options =
          if override.kind == :belongs_to and
               not Keyword.has_key?(override.options, :define_field) and
               association_foreign_key_present?(override.options, field_names) do
            Keyword.put(override.options, :define_field, false)
          else
            override.options
          end

        {:association, override.kind, override.name, override.type, options}
      end)

    explicit_names = MapSet.new(explicit, &elem(&1, 2))

    collisions =
      automatic
      |> Enum.filter(fn {_kind, name, _module, _options, _source} ->
        MapSet.member?(explicit_names, name)
      end)
      |> Enum.map(fn {_kind, name, _module, _options, _source} -> name end)
      |> Enum.uniq()

    automatic =
      Enum.reject(automatic, fn {_kind, name, _module, _options, _source} ->
        name in collisions
      end)

    collision_diagnostics =
      Enum.map(collisions, fn name ->
        warning(
          :association_override_replaced,
          "Association #{inspect(name)} on #{inspect(table_module(table))} is defined by an explicit override."
        )
      end)

    duplicate_names =
      (Enum.map(automatic, &elem(&1, 1)) ++ Enum.map(explicit, &elem(&1, 2)))
      |> Enum.group_by(& &1)
      |> Enum.filter(fn {_name, values} -> length(values) > 1 end)
      |> Enum.map(&elem(&1, 0))

    duplicate_diagnostics =
      Enum.map(duplicate_names, fn name ->
        warning(
          :ambiguous_association,
          "#{inspect(table_module(table))} has more than one possible association named #{inspect(name)}. PostgresToEcto omitted that association; use `skip_assocs [#{inspect(name)}]` or a named association override."
        )
      end)

    specs =
      (Enum.map(automatic, fn {kind, name, module, options, _source} ->
         {:association, kind, name, module, options}
       end) ++ explicit)
      |> Enum.reject(fn {:association, _kind, name, _module, _options} ->
        name in duplicate_names
      end)

    {specs, collision_diagnostics ++ duplicate_diagnostics}
  end

  defp automatic_associations(table, table_by_identity, field_names) do
    belongs_to =
      table.foreign_keys
      |> Enum.filter(&Map.get(&1, :selected_target?, false))
      |> Enum.filter(
        &(length(Map.get(&1, :source_columns, [])) == 1 and
            length(Map.get(&1, :target_columns, [])) == 1)
      )
      |> Enum.flat_map(fn foreign_key ->
        source = List.first(foreign_key.source_columns)
        target_identity = foreign_key.target_identity
        target = Map.get(table_by_identity, target_identity)

        if target do
          name = association_name(source, target)
          foreign_key_field = Map.get(field_names, source, field_name(source))
          reference = target_field_name(target, List.first(foreign_key.target_columns))
          options = [foreign_key: foreign_key_field, references: reference, define_field: false]
          [{:belongs_to, name, table_module(target), options, source}]
        else
          []
        end
      end)

    reverse =
      table_by_identity
      |> Enum.flat_map(fn {_identity, source_table} ->
        source_table.foreign_keys
        |> Enum.filter(&Map.get(&1, :selected_target?, false))
        |> Enum.filter(&(Map.get(&1, :target_identity) == table_identity(table)))
        |> Enum.filter(
          &(length(Map.get(&1, :source_columns, [])) == 1 and
              length(Map.get(&1, :target_columns, [])) == 1)
        )
        |> Enum.map(fn foreign_key ->
          source_column = List.first(foreign_key.source_columns)
          target_column = List.first(foreign_key.target_columns)
          source_module = table_module(source_table)

          kind =
            if unique_reference?(source_table, foreign_key.source_columns),
              do: :has_one,
              else: :has_many

          name = reverse_association_name(kind, source_table)

          options = [
            foreign_key: source_field_name(source_table, source_column),
            references: target_field_name(table, target_column)
          ]

          {kind, name, source_module, options, source_table}
        end)
      end)

    belongs_to ++ reverse
  end

  defp unique_reference?(table, source_columns) do
    source_columns == Map.get(table, :primary_key, []) or
      (non_null_columns?(table, source_columns) and
         Enum.any?(Map.get(table, :indexes, []), fn index ->
           Map.get(index, :unique?, false) and
             Map.get(index, :mapping_disposition, :exact) == :exact and
             Map.get(index, :columns, []) == source_columns
         end))
  end

  defp non_null_columns?(table, source_columns) do
    Enum.all?(source_columns, fn source ->
      case Enum.find(Map.get(table, :columns, []), &(&1.name == source)) do
        %{nullable: false} -> true
        %{primary_key?: true} -> true
        _ -> false
      end
    end)
  end

  defp unselected_reference_diagnostics(table) do
    table.foreign_keys
    |> Enum.filter(&(Map.get(&1, :selected_target?, false) == false))
    |> Enum.map(fn foreign_key ->
      warning(
        :unselected_referenced_table,
        "#{identity_text(table.identity)}.#{Enum.join(foreign_key.source_columns, ", ")} points to #{identity_text(foreign_key.target_identity)}, but that table is not selected. PostgresToEcto kept the field and omitted its association. Add the referenced table to the generator profile to include it."
      )
    end)
  end

  defp render_settings(table, columns) do
    conventional? = conventional_primary_key?(table, columns)

    settings =
      []
      |> maybe_append(not conventional?, "@primary_key false")
      |> maybe_append(
        table.identity.schema != "public",
        "@schema_prefix #{inspect(table.identity.schema)}"
      )

    Enum.join(settings, "\n")
  end

  defp region_map(settings, specs) do
    fields = Enum.map_join(specs, "\n", &render_spec/1)

    generated_fields =
      if fields == "" do
        "generated_fields do\nend"
      else
        "generated_fields do\n#{indent(fields, 2)}\nend"
      end

    regions = %{generated_fields: format_generated_region(generated_fields)}

    if settings == "",
      do: regions,
      else:
        Map.put(
          regions,
          :generated_settings,
          format_generated_region("generated_settings do\n#{indent(settings, 2)}\nend")
        )
  end

  defp format_generated_region(source) do
    source
    |> Code.format_string!(formatter_options())
    |> IO.iodata_to_binary()
    |> String.trim()
  rescue
    _exception -> source
  end

  defp render_source(profile, module, table, regions, region_names, existing_source, options) do
    show_comment? = Keyword.get(Map.get(profile, :options, []), :show_generated_key_comment, true)

    if is_nil(existing_source) do
      new_source(module, table, regions, region_names, show_comment?)
    else
      update_source(module, table, existing_source, regions, region_names, show_comment?, options)
    end
  end

  defp new_source(module, table, regions, region_names, show_comment?) do
    key_comment =
      if show_comment?,
        do: "  # Generated by PostgresToEcto. Do not modify this key manually.\n",
        else: ""

    settings = Map.get(regions, :generated_settings)
    fields = Map.fetch!(regions, :generated_fields)

    source =
      """
      defmodule #{inspect(module)} do
        use Ecto.Schema
        use PostgresToEcto.Schema

      #{key_comment}  @postgres_to_ecto_key "postgreste1:placeholder"

      #{settings && settings <> "\n\n"}  schema #{inspect(table.identity.table)} do
        #{fields}
      end
      end
      """
      |> Code.format_string!(formatter_options())
      |> IO.iodata_to_binary()
      |> normalize_source()

    with {:ok, key} <- Managed.key_for_source(module, source, region_names),
         {:ok, updated} <- Managed.update_key(source, key),
         {:ok, _ast} <- parse_source(updated) do
      {:ok, updated, key, []}
    else
      {:error, reason} ->
        {:error,
         [
           error(
             :invalid_generated_schema,
             "Generated schema could not be parsed safely (#{inspect(reason)})."
           )
         ]}
    end
  rescue
    _exception ->
      {:error,
       [error(:invalid_generated_schema, "Generated schema could not be formatted safely.")]}
  end

  defp update_source(module, table, source, regions, region_names, show_comment?, options) do
    force? = Keyword.get(options, :force, false)
    known_region_names = [:generated_settings, :generated_fields]

    case managed_region_state(source, known_region_names, region_names) do
      {:ok, present_region_names, existing_regions, duplicate?} ->
        update_managed_source(
          module,
          source,
          regions,
          region_names,
          present_region_names,
          existing_regions,
          duplicate?,
          show_comment?,
          force?,
          table
        )

      {:error, :unowned_file} when force? ->
        with {:ok, replacement, key, diagnostics} <-
               new_source(module, table, regions, region_names, show_comment?) do
          {:ok, replacement, key,
           [
             warning(
               :force_replaced_unowned_file,
               "Force replaced the unmanaged schema file #{table_path(table)}."
             )
             | diagnostics
           ]}
        else
          {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
          {:error, replacement_reason} -> {:error, [source_error(replacement_reason)]}
        end

      {:error, reason} ->
        {:error, [source_error(reason)]}
    end
  end

  defp update_managed_source(
         module,
         source,
         regions,
         region_names,
         present_region_names,
         existing_regions,
         duplicate?,
         show_comment?,
         force?,
         table
       ) do
    key_result =
      if duplicate?,
        do: {:error, [source_error(:region_count_mismatch)]},
        else: ensure_embedded_key(module, source, present_region_names)

    with :ok <- allow_key_result(key_result, force?),
         :ok <- detect_user_collisions(source, present_region_names, regions),
         {:ok, patched} <-
           patch_existing_regions(
             source,
             regions,
             region_names,
             present_region_names,
             existing_regions,
             duplicate?
           ),
         {:ok, key} <- Managed.key_for_source(module, patched, region_names),
         {:ok, updated} <- Managed.update_key(patched, key),
         {:ok, updated} <- update_key_comment(updated, show_comment?),
         {:ok, _ast} <- parse_source(updated) do
      diagnostics =
        if key_result == :ok do
          []
        else
          [
            warning(
              :force_reset_managed_file,
              "Force reset the managed schema regions in #{table_path(table)}."
            )
          ]
        end

      {:ok, updated, key, diagnostics}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, reason} -> {:error, [source_error(reason)]}
    end
  end

  defp managed_region_state(source, known_region_names, _expected_region_names) do
    with {:ok, regions} <- Managed.find_regions(source, known_region_names) do
      present_region_names = regions |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

      duplicate? =
        Enum.any?(known_region_names, fn name ->
          Enum.count(regions, &(elem(&1, 0) == name)) > 1
        end)

      if present_region_names == [] do
        {:error, :unowned_file}
      else
        {:ok, present_region_names, regions, duplicate?}
      end
    else
      {:error, reason} ->
        if managed_source_marked?(source, known_region_names),
          do: {:error, :invalid_managed_schema},
          else: {:error, reason}
    end
  end

  defp managed_source_marked?(source, known_region_names) do
    Managed.extract_key(source) != :missing or
      Enum.any?(known_region_names, &String.contains?(source, Atom.to_string(&1)))
  end

  defp patch_existing_regions(
         source,
         regions,
         region_names,
         _present_region_names,
         existing_regions,
         true
       ) do
    source = remove_region_ranges(source, existing_regions)
    add_missing_regions(source, regions, region_names, [])
  end

  defp patch_existing_regions(
         source,
         regions,
         region_names,
         present_region_names,
         _existing_regions,
         false
       ) do
    with {:ok, patched} <-
           Managed.patch_regions(source, replacement_regions(regions, present_region_names)) do
      add_missing_regions(patched, regions, region_names, present_region_names)
    end
  end

  defp remove_region_ranges(source, regions) do
    ranges =
      regions
      |> Enum.map(fn {_name, start, finish} -> {start, finish} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.reduce([], fn {start, finish}, acc ->
        case acc do
          [{last_start, last_finish} | rest] when start <= last_finish ->
            [{last_start, max(last_finish, finish)} | rest]

          _ ->
            [{start, finish} | acc]
        end
      end)
      |> Enum.sort_by(&elem(&1, 0), :desc)

    Enum.reduce(ranges, source, fn {start, finish}, current ->
      binary_part(current, 0, start) <> binary_part(current, finish, byte_size(current) - finish)
    end)
  end

  defp replacement_regions(regions, present_region_names) do
    removals = Map.new(present_region_names, &{&1, ""})
    Map.merge(removals, regions) |> Map.take(present_region_names)
  end

  defp add_missing_regions(source, regions, region_names, present_region_names) do
    region_names
    |> Enum.reject(&(&1 in present_region_names))
    |> Enum.reduce_while({:ok, source}, fn name, {:ok, current} ->
      case insert_region(current, name, Map.fetch!(regions, name)) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_region(source, :generated_settings, replacement) do
    case Regex.run(~r/^([ \t]*)(schema\b[^\n]*\bdo[ \t]*)$/m, source) do
      [full, indent, _schema_line] ->
        replacement = indent_lines_with_prefix(replacement, indent)
        {:ok, String.replace(source, full, replacement <> "\n\n" <> full, global: false)}

      _ ->
        {:error, :missing_region_anchor}
    end
  end

  defp insert_region(source, :generated_fields, replacement) do
    case Regex.run(~r/^([ \t]*)(schema\b[^\n]*\bdo[ \t]*)$/m, source) do
      [full, indent, _schema_line] ->
        replacement = indent_lines_with_prefix(replacement, indent <> "  ")
        {:ok, String.replace(source, full, full <> "\n" <> replacement, global: false)}

      _ ->
        {:error, :missing_region_anchor}
    end
  end

  defp insert_region(_source, _name, _replacement), do: {:error, :missing_region_anchor}

  defp indent_lines_with_prefix(text, prefix) do
    text
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.map_join("\n", fn
      {line, 0} -> prefix <> line
      {line, _index} -> if(line == "", do: line, else: prefix <> line)
    end)
  end

  defp allow_key_result(:ok, _force?), do: :ok
  defp allow_key_result(_result, true), do: :ok
  defp allow_key_result({:error, diagnostics}, false), do: {:error, diagnostics}

  defp ensure_embedded_key(module, source, region_names) do
    with {:ok, embedded} <- Managed.extract_key(source),
         {:ok, current} <- Managed.key_for_source(module, source, region_names) do
      if embedded == current, do: :ok, else: {:error, [source_error(:mismatched_key)]}
    else
      :missing -> {:error, [source_error(:missing_key)]}
      {:error, reason} -> {:error, [source_error(reason)]}
    end
  end

  defp detect_user_collisions(source, region_names, regions) do
    generated_names = generated_names(regions)
    {:ok, managed_regions} = Managed.find_regions(source, region_names)
    ranges = Enum.map(managed_regions, fn {_name, start, finish} -> {start, finish} end)

    collisions =
      case Sourceror.parse_string(source) do
        {:ok, ast} ->
          ast
          |> Macro.prewalk([], fn
            {name, meta, [first | _]} = node, acc when name in @field_calls and is_list(meta) ->
              position = metadata_offset(source, meta)
              first = literal_atom(first)

              if is_integer(position) and
                   Enum.any?(ranges, fn {start, finish} ->
                     position >= start and position < finish
                   end) do
                {node, acc}
              else
                {node, [first | acc]}
              end

            node, acc ->
              {node, acc}
          end)
          |> elem(1)
          |> Enum.filter(&is_atom/1)
          |> Enum.filter(&MapSet.member?(generated_names, &1))
          |> Enum.uniq()

        {:error, _} ->
          []
      end

    if collisions == [] do
      :ok
    else
      {:error,
       Enum.map(collisions, fn name ->
         error(
           :schema_name_collision,
           "Schema already defines #{inspect(name)} outside PostgresToEcto's generated region. Use `skip_assocs [#{inspect(name)}]`, rename the override, or remove the user declaration before regenerating."
         )
       end)}
    end
  end

  defp generated_names(regions) do
    regions
    |> Map.get(:generated_fields, "")
    |> then(fn fields ->
      case Sourceror.parse_string(fields) do
        {:ok, ast} ->
          ast
          |> Macro.prewalk([], fn
            {name, _meta, [first | _]} = node, acc when name in @field_calls ->
              {node, [literal_atom(first) | acc]}

            node, acc ->
              {node, acc}
          end)
          |> elem(1)
          |> Enum.filter(&is_atom/1)
          |> MapSet.new()

        _ ->
          MapSet.new()
      end
    end)
  end

  defp render_spec({:field, name, type, options}) do
    "field #{inspect(name)}, #{render_type(type)}#{render_options(options)}"
  end

  defp render_spec({:association, kind, name, type, options}) do
    "#{kind} #{inspect(name)}, #{inspect(type)}#{render_options(options)}"
  end

  defp render_options([]), do: ""
  defp render_options(options), do: ", " <> Enum.map_join(options, ", ", &render_option/1)

  defp render_option({key, value}), do: "#{key}: #{inspect(value)}"

  defp render_type(type) when is_atom(type) do
    if type in [:id, :integer, :string, :boolean], do: inspect(type), else: inspect(type)
  end

  defp render_type(type), do: inspect(type)

  defp column_type(column) do
    case get_in(column, [:mapping, :schema]) do
      nil ->
        case get_in(column, [:mapping, :migration]) do
          :bigserial -> :id
          :bigint -> :integer
          :text -> :string
          type when type in [:id, :integer, :string, :boolean] -> type
          _type -> nil
        end

      type ->
        type
    end
  end

  defp safe_default(column) do
    case Map.get(column, :default, %{}) do
      %{classification: :safe_literal, value: value} -> value
      _ -> nil
    end
  end

  defp database_default?(column) do
    get_in(column, [:default, :classification]) == :database_expression
  end

  defp implicit_primary_key?(table, column),
    do: conventional_primary_key?(table, Map.get(table, :columns, [])) and column.name == "id"

  defp conventional_primary_key?(table, columns) do
    Map.get(table, :primary_key) == ["id"] and
      case Enum.find(columns, &(&1.name == "id")) do
        %{serial_kind: :bigserial} -> true
        %{mapping: %{schema: schema}} when schema in [:id, :integer] -> true
        _ -> false
      end
  end

  defp field_name(source) do
    source
    |> String.replace(~r/[^A-Za-z0-9_]/, "_")
    |> Macro.underscore()
    |> String.trim_leading("_")
    |> then(fn value ->
      if value == "" or value =~ ~r/^\d/, do: "field_" <> value, else: value
    end)
    |> String.to_atom()
  end

  defp association_name(source, target) do
    source
    |> String.trim_trailing("_id")
    |> case do
      "" -> module_name(target)
      value -> field_name(value)
    end
  end

  defp reverse_association_name(:has_one, table), do: field_name(module_name(table))
  defp reverse_association_name(:has_many, table), do: field_name(table.identity.table)

  defp module_name(table) do
    table_module(table) |> Module.split() |> List.last() |> Macro.underscore()
  end

  defp target_field_name(table, source) do
    table
    |> Map.get(:columns, [])
    |> Enum.find(%{name: source}, &(&1.name == source))
    |> then(&field_name(&1.name))
  end

  defp source_field_name(table, source) do
    table
    |> table_overrides()
    |> Enum.find_value(field_name(source), fn
      %{kind: :field, name: name, options: options} ->
        if to_string(Keyword.get(options, :source, name)) == source, do: name

      _override ->
        nil
    end)
  end

  defp association_foreign_key_present?(options, field_names) do
    foreign_key = Keyword.get(options, :foreign_key)
    is_atom(foreign_key) and foreign_key in Map.values(field_names)
  end

  defp unusual_identifier_diagnostics(table, source, field_name, override) do
    if (not is_nil(override) and Keyword.has_key?(override.options, :source)) or
         source == Atom.to_string(field_name) do
      []
    else
      [
        warning(
          :unusual_identifier,
          "#{identity_text(table.identity)}.#{source} uses generated field #{inspect(field_name)} with `source: #{inspect(source)}`."
        )
      ]
    end
  end

  defp table_module(table), do: Map.get(table, :module) || get_in(table, [:selection, :module])
  defp table_path(table), do: Map.get(table, :file) || get_in(table, [:selection, :file])

  defp table_overrides(table),
    do: Map.get(table, :overrides, get_in(table, [:selection, :overrides]) || [])

  defp table_identity(table), do: {table.identity.schema, table.identity.table}
  defp identity_text(%{schema: schema, table: table}), do: "#{schema}.#{table}"
  defp identity_text({schema, table}), do: "#{schema}.#{table}"

  defp literal_atom({:__block__, _meta, [value]}) when is_atom(value), do: value
  defp literal_atom(value), do: value

  defp metadata_offset(source, meta) do
    case {Keyword.get(meta, :line), Keyword.get(meta, :column)} do
      {line, column} when is_integer(line) and is_integer(column) ->
        source
        |> :binary.split("\n", [:global])
        |> Enum.take(line - 1)
        |> Enum.map(&byte_size/1)
        |> Enum.sum()
        |> Kernel.+(max(line - 1, 0))
        |> Kernel.+(column - 1)

      _ ->
        nil
    end
  end

  defp update_key_comment(source, true) do
    if String.contains?(source, "# Generated by PostgresToEcto. Do not modify this key manually.") do
      {:ok, source}
    else
      case Regex.run(~r/(^[ \t]*@postgres_to_ecto_key[ \t]+"postgreste1:[^"]+"[ \t]*$)/m, source,
             capture: :all_but_first
           ) do
        [key_line] ->
          indent = Regex.run(~r/^[ \t]*/, key_line) |> List.first()
          comment = indent <> "# Generated by PostgresToEcto. Do not modify this key manually."

          {:ok, String.replace(source, key_line, comment <> "\n" <> key_line, global: false)}

        _ ->
          {:error, :missing_key_anchor}
      end
    end
  end

  defp update_key_comment(source, false) do
    {:ok,
     Regex.replace(
       ~r/^[ \t]*# Generated by PostgresToEcto\. Do not modify this key manually\.[ \t]*\n/m,
       source,
       ""
     )}
  end

  defp formatter_options do
    [
      locals_without_parens: [
        generated_settings: 1,
        generated_fields: 1,
        field: 2,
        field: 3,
        belongs_to: 2,
        belongs_to: 3,
        has_one: 2,
        has_one: 3,
        has_many: 2,
        has_many: 3
      ]
    ]
  end

  defp normalize_source(source), do: String.trim_trailing(source) <> "\n"

  defp parse_source(source) do
    case Sourceror.parse_string(source) do
      {:ok, _ast} -> {:ok, source}
      {:error, error} -> {:error, {:parse_error, Exception.message(error)}}
    end
  end

  defp source_error(:missing_key),
    do: error(:managed_key_missing, "The existing schema has no PostgresToEcto managed key.")

  defp source_error(:invalid_key),
    do:
      error(
        :managed_key_invalid,
        "The existing schema has an invalid PostgresToEcto managed key."
      )

  defp source_error(:unowned_file),
    do:
      error(
        :unowned_file,
        "The existing schema file is not managed by PostgresToEcto. Use force to replace it."
      )

  defp source_error(:mismatched_key),
    do:
      error(
        :managed_key_mismatch,
        "The existing schema has been changed inside a managed region. Restore the managed key or review the file before regenerating."
      )

  defp source_error(:region_count_mismatch),
    do:
      error(
        :invalid_managed_schema,
        "The existing schema does not contain exactly one of each expected generated region."
      )

  defp source_error({:parse_error, message}),
    do: error(:invalid_managed_schema, "Could not parse the existing schema: #{message}.")

  defp source_error(reason),
    do:
      error(
        :invalid_managed_schema,
        "The existing schema could not be updated safely (#{inspect(reason)})."
      )

  defp indent(text, count) do
    prefix = String.duplicate(" ", count)

    text
    |> String.split("\n")
    |> Enum.map_join("\n", fn line -> if line == "", do: line, else: prefix <> line end)
  end

  defp maybe_put(options, _key, _value, false), do: options

  defp maybe_put(options, key, value, _default) when not is_nil(value),
    do: Keyword.put(options, key, value)

  defp maybe_put(options, _key, _value, _default), do: options
  defp maybe_append(lines, true, line), do: lines ++ [line]
  defp maybe_append(lines, false, _line), do: lines
  defp has_errors?(diagnostics), do: Enum.any?(diagnostics, &(&1.severity == :error))
  defp error(code, message), do: %Diagnostic{severity: :error, code: code, message: message}
  defp warning(code, message), do: %Diagnostic{severity: :warning, code: code, message: message}
end
