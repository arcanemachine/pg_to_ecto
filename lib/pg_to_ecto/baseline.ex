defmodule PgToEcto.Baseline do
  @moduledoc false

  alias PgToEcto.{Diagnostic, Managed}

  @region_name :generated_change
  @type render_result :: %{
          source: String.t(),
          diagnostics: [Diagnostic.t()],
          key: String.t()
        }

  @doc false
  @spec render(map(), map(), String.t() | nil) ::
          {:ok, render_result()} | {:error, [Diagnostic.t()]}
  def render(profile, model, existing_source \\ nil) do
    module = migration_module(profile.repo)
    {diagnostics, tables} = diagnostics_and_tables(model)

    with {:ok, ordered_tables} <- order_tables(tables, diagnostics),
         false <- has_errors?(diagnostics),
         {:ok, source, key} <- render_source(profile, module, ordered_tables, existing_source) do
      {:ok, %{source: source, diagnostics: diagnostics, key: key}}
    else
      true -> {:error, diagnostics}
      {:error, diagnostics} -> {:error, diagnostics}
    end
  end

  @doc false
  @spec migration_module(module()) :: module()
  def migration_module(repo) when is_atom(repo) do
    Module.concat([repo, Migrations, PgToEcto])
  end

  defp diagnostics_and_tables(model) do
    Enum.reduce(model.tables, {[], []}, fn table, {diagnostics, tables} ->
      table_diagnostics = table_diagnostics(table)
      {diagnostics ++ table_diagnostics, tables ++ [table]}
    end)
  end

  defp table_diagnostics(table) do
    relation_diagnostics =
      case table.relation_kind do
        :table ->
          []

        relation_kind ->
          [
            error(
              :unsupported_relation,
              "#{identity_text(table.identity)} is #{inspect(relation_kind)}. " <>
                "Baseline rendering supports ordinary tables only."
            )
          ]
      end

    column_diagnostics =
      Enum.flat_map(table.columns, fn column ->
        case get_in(column, [:mapping, :disposition]) do
          :blocking ->
            [
              error(
                :unsupported_column_type,
                "#{identity_text(table.identity)}.#{column.name} has PostgreSQL type " <>
                  "#{inspect(column.type.postgres.formatted || column.type.postgres.name)} " <>
                  "that cannot be rendered safely in the baseline."
              )
            ]

          _ ->
            []
        end
      end)

    column_names = MapSet.new(table.columns, & &1.name)

    identifier_diagnostics =
      Enum.flat_map(table.columns, fn column ->
        if simple_identifier?(column.name) do
          []
        else
          [
            error(
              :unsupported_column_identifier,
              "#{identity_text(table.identity)}.#{column.name} cannot be rendered by the Wave 1 Ecto migration DSL."
            )
          ]
        end
      end)

    primary_key_diagnostics =
      Enum.flat_map(table.primary_key || [], fn column_name ->
        if MapSet.member?(column_names, column_name) do
          []
        else
          [
            error(
              :invalid_primary_key,
              "#{identity_text(table.identity)} primary key column #{column_name} was not found in the selected columns."
            )
          ]
        end
      end)

    foreign_key_diagnostics =
      Enum.flat_map(table.foreign_keys, &foreign_key_diagnostics(table, &1, column_names))

    index_diagnostics =
      Enum.flat_map(table.indexes, fn index ->
        if index.mapping_disposition == :exact and
             Enum.all?(
               index.columns,
               &(MapSet.member?(column_names, &1) and simple_identifier?(&1))
             ) do
          []
        else
          index_diagnostics_for(table, index)
        end
      end)

    relation_diagnostics ++
      column_diagnostics ++
      identifier_diagnostics ++
      primary_key_diagnostics ++
      foreign_key_diagnostics ++
      index_diagnostics
  end

  defp foreign_key_diagnostics(table, foreign_key, column_names) do
    cond do
      foreign_key.update_action == :set_default or foreign_key.delete_action == :set_default ->
        [
          error(
            :unsupported_foreign_key_action,
            "Foreign key #{foreign_key.name} on #{identity_text(table.identity)} uses SET DEFAULT " <>
              "for #{set_default_actions(foreign_key)}. Ecto migrations cannot preserve this " <>
              "referential action; use CASCADE, NO ACTION, RESTRICT, or SET NULL instead."
          )
        ]

      foreign_key.mapping_disposition == :omitted_with_warning ->
        source_column = Enum.join(foreign_key.source_columns, ", ")
        target = identity_text(foreign_key.target_identity)

        [
          warning(
            :unselected_referenced_table,
            "#{identity_text(table.identity)}.#{source_column} points to #{target}, but " <>
              "that table is not selected. PgToEcto kept the local column and omitted its " <>
              "foreign key. Add table #{inspect(target)}, module: MyApp.Table to include it."
          )
        ]

      Enum.any?(foreign_key.source_columns, &(not MapSet.member?(column_names, &1))) ->
        [
          error(
            :invalid_foreign_key,
            "Foreign key #{foreign_key.name} on #{identity_text(table.identity)} names a source column that was not selected."
          )
        ]

      not simple_identifier?(List.first(foreign_key.target_columns)) ->
        [
          error(
            :unsupported_foreign_key_identifier,
            "Foreign key #{foreign_key.name} on #{identity_text(table.identity)} references a column that cannot be rendered by the Wave 1 Ecto migration DSL."
          )
        ]

      length(foreign_key.source_columns) != 1 or length(foreign_key.target_columns) != 1 ->
        [
          error(
            :unsupported_foreign_key,
            "Foreign key #{foreign_key.name} on #{identity_text(table.identity)} is composite. " <>
              "The Wave 1 baseline supports single-column foreign keys only."
          )
        ]

      foreign_key.update_action == :unknown or foreign_key.delete_action == :unknown ->
        [
          error(
            :unsupported_foreign_key_action,
            "Foreign key #{foreign_key.name} on #{identity_text(table.identity)} has an " <>
              "unknown PostgreSQL update or delete action."
          )
        ]

      true ->
        []
    end
  end

  defp index_diagnostics_for(table, index) do
    if index.mapping_disposition == :omitted_with_warning do
      [
        warning(
          :unsupported_index,
          "#{identity_text(table.identity)} index #{index.name} was not rendered because " <>
            "expression and partial indexes are outside the baseline Wave 1 surface."
        )
      ]
    else
      [
        error(
          :invalid_index,
          "#{identity_text(table.identity)} index #{index.name} names a column that was not selected."
        )
      ]
    end
  end

  defp order_tables(tables, diagnostics) do
    identities = Enum.map(tables, &table_identity/1)
    table_by_identity = Map.new(tables, &{table_identity(&1), &1})
    order = Map.new(Enum.with_index(identities), fn {identity, index} -> {identity, index} end)

    case visit_tables(identities, table_by_identity, order, MapSet.new(), MapSet.new(), []) do
      {:ok, ordered} ->
        {:ok, ordered}

      {:error, cycle} ->
        {:error,
         diagnostics ++
           [
             error(
               :cyclic_foreign_keys,
               "Selected tables contain a foreign-key cycle: #{Enum.map_join(cycle, " -> ", &identity_text/1)}. " <>
                 "The baseline cannot safely order this cycle without deferred constraints."
             )
           ]}
    end
  end

  defp visit_tables([], _table_by_identity, _order, _visiting, _visited, ordered),
    do: {:ok, ordered}

  defp visit_tables([identity | rest], table_by_identity, order, visiting, visited, ordered) do
    if MapSet.member?(visited, identity) do
      visit_tables(rest, table_by_identity, order, visiting, visited, ordered)
    else
      case visit_table(identity, table_by_identity, order, visiting, visited, ordered) do
        {:ok, visited, ordered} ->
          visit_tables(rest, table_by_identity, order, visiting, visited, ordered)

        {:error, cycle} ->
          {:error, cycle}
      end
    end
  end

  defp visit_table(identity, table_by_identity, order, visiting, visited, ordered) do
    cond do
      MapSet.member?(visited, identity) ->
        {:ok, visited, ordered}

      MapSet.member?(visiting, identity) ->
        {:error, [identity]}

      true ->
        table = Map.fetch!(table_by_identity, identity)
        visiting = MapSet.put(visiting, identity)

        dependencies =
          table.foreign_keys
          |> Enum.filter(& &1.selected_target?)
          |> Enum.map(& &1.target_identity)
          |> Enum.filter(&Map.has_key?(table_by_identity, &1))
          |> Enum.sort_by(&Map.fetch!(order, &1))

        with {:ok, visited, ordered} <-
               visit_dependencies(
                 dependencies,
                 table_by_identity,
                 order,
                 visiting,
                 visited,
                 ordered
               ) do
          {:ok, MapSet.put(visited, identity), ordered ++ [table]}
        end
    end
  end

  defp visit_dependencies([], _table_by_identity, _order, _visiting, visited, ordered),
    do: {:ok, visited, ordered}

  defp visit_dependencies(
         [dependency | rest],
         table_by_identity,
         order,
         visiting,
         visited,
         ordered
       ) do
    case visit_table(dependency, table_by_identity, order, visiting, visited, ordered) do
      {:ok, visited, ordered} ->
        visit_dependencies(rest, table_by_identity, order, visiting, visited, ordered)

      {:error, cycle} ->
        {:error, [dependency | cycle]}
    end
  end

  defp render_source(profile, module, tables, existing_source) do
    with {:ok, region} <- format_region(render_region(tables)) do
      render_formatted_source(profile, module, region, existing_source)
    end
  end

  defp render_formatted_source(profile, module, region, existing_source) do
    case existing_source do
      nil ->
        source =
          new_source(
            module,
            region,
            Keyword.get(profile.options, :show_generated_key_comment, true)
          )

        finalize_source(module, source)

      source when is_binary(source) ->
        render_existing_source(
          module,
          source,
          region,
          Keyword.get(profile.options, :show_generated_key_comment, true)
        )
    end
  end

  defp format_region(region) do
    source = """
    def change do
      generated_change do
    #{region}
      end
    end
    """

    formatter_options = [
      locals_without_parens: [
        add: 2,
        add: 3,
        create: 1,
        create: 2,
        execute: 1,
        execute: 2,
        generated_change: 1
      ]
    ]

    try do
      formatted =
        source
        |> Code.format_string!(formatter_options)
        |> IO.iodata_to_binary()
        |> normalize_formatter_output()

      with {:ok, [{@region_name, start, finish}]} <-
             Managed.find_regions(formatted, [@region_name]) do
        formatted_region = binary_part(formatted, start, finish - start)
        {:ok, dedent_region(formatted_region)}
      else
        _ ->
          {:error,
           [
             error(
               :invalid_generated_migration,
               "Generated migration operations could not be formatted safely."
             )
           ]}
      end
    rescue
      _exception ->
        {:error,
         [
           error(
             :invalid_generated_migration,
             "Generated migration operations could not be formatted safely."
           )
         ]}
    end
  end

  defp dedent_region(region) do
    region
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.map_join("\n", fn
      {line, 0} ->
        line

      {line, _index} ->
        cond do
          String.trim(line) == "" -> ""
          String.starts_with?(line, "  ") -> String.slice(line, 2..-1//1)
          true -> line
        end
    end)
  end

  defp render_existing_source(module, source, region, show_comment?) do
    with {:ok, regions} <- Managed.find_regions(source, [@region_name]),
         :ok <- ensure_one_region(regions),
         {:ok, current_key} <- Managed.key_for_source(module, source, [@region_name]),
         :ok <- validate_embedded_key(source, current_key),
         {:ok, patched} <- Managed.patch_regions(source, %{@region_name => region}),
         {:ok, key} <- Managed.key_for_source(module, patched, [@region_name]),
         {:ok, updated} <- Managed.update_key(patched, key),
         {:ok, updated} <- update_key_comment(updated, show_comment?) do
      {:ok, updated, key}
    else
      {:error, {:parse_error, message}} ->
        {:error,
         [
           error(
             :invalid_managed_migration,
             "Could not parse the existing baseline migration: #{message}."
           )
         ]}

      {:error, :missing_key} ->
        {:error,
         [
           error(
             :managed_key_missing,
             "The existing baseline migration has no PgToEcto managed key."
           )
         ]}

      {:error, :mismatched_key} ->
        {:error,
         [
           error(
             :managed_key_mismatch,
             "The existing baseline migration has been changed outside PgToEcto. Restore the managed key or review the file before regenerating."
           )
         ]}

      {:error, reason} ->
        {:error,
         [
           error(
             :invalid_managed_migration,
             "The existing baseline migration could not be updated safely (#{inspect(reason)})."
           )
         ]}
    end
  end

  defp validate_embedded_key(source, current_key) do
    case Managed.extract_key(source) do
      {:ok, ^current_key} -> :ok
      {:ok, _actual} -> {:error, :mismatched_key}
      :missing -> {:error, :missing_key}
    end
  end

  defp ensure_one_region(regions) do
    if Enum.count(regions, &(&1 |> elem(0) == @region_name)) == 1 do
      :ok
    else
      {:error, :region_count_mismatch}
    end
  end

  defp update_key_comment(source, true) do
    if String.contains?(source, "# Generated by PgToEcto. Do not modify this key manually.") do
      {:ok, source}
    else
      case Regex.run(~r/(^\s*@pg_to_ecto_key\s+"pgte1:[^"]+"\s*$)/m, source,
             capture: :all_but_first
           ) do
        [key_line] ->
          {:ok,
           String.replace(
             source,
             key_line,
             "# Generated by PgToEcto. Do not modify this key manually.\n" <> key_line,
             global: false
           )}

        _ ->
          {:error, :missing_key_anchor}
      end
    end
  end

  defp update_key_comment(source, false) do
    {:ok,
     Regex.replace(
       ~r/^\s*# Generated by PgToEcto\. Do not modify this key manually\.\n/m,
       source,
       ""
     )}
  end

  defp new_source(module, region, show_comment?) do
    key_comment =
      if show_comment?,
        do: "  # Generated by PgToEcto. Do not modify this key manually.\n",
        else: ""

    """
    defmodule #{inspect(module)} do
      use Ecto.Migration
      use PgToEcto.Migration

    #{key_comment}  @pg_to_ecto_key "pgte1:placeholder"

      def change do
    #{region}
      end
    end
    """
  end

  defp finalize_source(module, source) do
    formatter_options = [
      locals_without_parens: [
        add: 2,
        add: 3,
        create: 1,
        create: 2,
        execute: 1,
        execute: 2,
        generated_change: 1
      ]
    ]

    formatted =
      source
      |> Code.format_string!(formatter_options)
      |> IO.iodata_to_binary()
      |> normalize_formatter_output()

    with {:ok, key} <- Managed.key_for_source(module, formatted, [@region_name]),
         {:ok, updated} <- Managed.update_key(formatted, key),
         {:ok, updated} <- parse_source(updated) do
      {:ok, updated, key}
    else
      {:error, reason} ->
        {:error,
         [
           error(
             :invalid_generated_migration,
             "Generated baseline migration could not be parsed safely (#{inspect(reason)}). "
           )
         ]}
    end
  end

  defp normalize_formatter_output(source) do
    source
    |> String.replace(~r/(^\s*)\), (null:)/m, "\\1),\n\\1\\2")
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  defp parse_source(source) do
    case Sourceror.parse_string(source) do
      {:ok, _ast} -> {:ok, source}
      {:error, error} -> {:error, {:parse_error, Exception.message(error)}}
    end
  end

  defp render_region(tables) do
    table_blocks = Enum.map(tables, &render_table/1)
    index_blocks = Enum.flat_map(tables, &render_indexes/1)

    (namespace_blocks(tables) ++ table_blocks ++ index_blocks)
    |> Enum.intersperse("\n")
    |> Enum.join("\n")
  end

  defp namespace_blocks(tables) do
    tables
    |> Enum.map(& &1.identity.schema)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == "public"))
    |> Enum.sort()
    |> Enum.map(fn schema ->
      quoted = quote_identifier(schema)

      "execute(\"CREATE SCHEMA #{quoted}\", \"DROP SCHEMA #{quoted}\")"
    end)
  end

  defp render_table(table) do
    table_options =
      ["primary_key: false"] ++
        if(table.identity.schema == "public",
          do: [],
          else: ["prefix: #{inspect(table.identity.schema)}"]
        )

    table_term = identifier_term(table.identity.table)
    foreign_keys = Map.new(table.foreign_keys, &{List.first(&1.source_columns), &1})
    primary_key = MapSet.new(table.primary_key || [])

    columns =
      Enum.map(table.columns, fn column ->
        render_column(
          column,
          Map.get(foreign_keys, column.name),
          MapSet.member?(primary_key, column.name),
          table.identity.schema
        )
      end)

    [
      "create table(#{table_term}, #{Enum.join(table_options, ", ")}) do",
      Enum.map_join(columns, "\n", &("  " <> &1)),
      "end"
    ]
    |> Enum.join("\n")
  end

  defp render_column(column, foreign_key, primary_key?, source_schema) do
    name = identifier_term(column.name)
    options = [if(primary_key?, do: "primary_key: true"), "null: #{column.nullable}"]
    options = options ++ default_options(column)

    case foreign_key do
      %{selected_target?: true} = foreign_key ->
        reference = render_reference(column, foreign_key, source_schema)
        "add #{name}, #{reference}, #{options |> Enum.reject(&is_nil/1) |> Enum.join(", ")}"

      _ ->
        type = inspect(column.mapping.migration)
        options = options |> Enum.reject(&is_nil/1) |> Enum.join(", ")
        "add #{name}, #{type}, #{options}"
    end
  end

  defp render_reference(column, foreign_key, source_schema) do
    target_table = identifier_term(elem(foreign_key.target_identity, 1))
    options = ["type: #{inspect(column.mapping.migration)}"]

    options =
      if elem(foreign_key.target_identity, 0) == source_schema,
        do: options,
        else: options ++ ["prefix: #{inspect(elem(foreign_key.target_identity, 0))}"]

    options =
      if List.first(foreign_key.target_columns) == "id",
        do: options,
        else: options ++ ["column: #{identifier_term(List.first(foreign_key.target_columns))}"]

    options = options ++ ["name: #{inspect(foreign_key.name)}"]

    options =
      if foreign_key.delete_action == :no_action,
        do: options,
        else: options ++ ["on_delete: #{inspect(delete_action(foreign_key.delete_action))}"]

    options =
      if foreign_key.update_action == :no_action,
        do: options,
        else: options ++ ["on_update: #{inspect(update_action(foreign_key.update_action))}"]

    "references(#{target_table}, #{Enum.join(options, ", ")})"
  end

  defp default_options(%{serial_kind: :bigserial}), do: []

  defp default_options(%{default: %{classification: :safe_literal, value: value}}),
    do: ["default: #{inspect(value)}"]

  defp default_options(%{
         default: %{classification: :database_expression, expression: expression}
       })
       when is_binary(expression), do: ["default: fragment(#{inspect(expression)})"]

  defp default_options(_column), do: []

  defp render_indexes(table) do
    table.indexes
    |> Enum.filter(&(&1.mapping_disposition == :exact))
    |> Enum.sort_by(& &1.name)
    |> Enum.map(fn index ->
      function = if index.unique?, do: "unique_index", else: "index"
      table_term = identifier_term(table.identity.table)
      columns = Enum.map_join(index.columns, ", ", &identifier_term/1)
      options = ["name: #{inspect(index.name)}"]

      options =
        if table.identity.schema == "public",
          do: options,
          else: options ++ ["prefix: #{inspect(table.identity.schema)}"]

      "create #{function}(#{table_term}, [#{columns}], #{Enum.join(options, ", ")})"
    end)
  end

  defp identifier_term(value) do
    if simple_identifier?(value), do: ":#{value}", else: inspect(value)
  end

  defp simple_identifier?(value),
    do: is_binary(value) and Regex.match?(~r/^[a-z_][a-z0-9_]*$/, value)

  defp quote_identifier(value), do: String.replace(value, "\"", "\"\"") |> then(&"\\\"#{&1}\\\"")

  defp delete_action(:cascade), do: :delete_all
  defp delete_action(:set_null), do: :nilify_all
  defp delete_action(:restrict), do: :restrict

  defp update_action(:cascade), do: :update_all
  defp update_action(:set_null), do: :nilify_all
  defp update_action(:restrict), do: :restrict

  defp set_default_actions(foreign_key) do
    [
      if(foreign_key.delete_action == :set_default, do: "delete", else: nil),
      if(foreign_key.update_action == :set_default, do: "update", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" and ")
  end

  defp table_identity(table), do: {table.identity.schema, table.identity.table}
  defp identity_text(%{schema: schema, table: table}), do: "#{schema}.#{table}"
  defp identity_text({schema, table}), do: "#{schema}.#{table}"
  defp has_errors?(diagnostics), do: Enum.any?(diagnostics, &(&1.severity == :error))
  defp error(code, message), do: %Diagnostic{severity: :error, code: code, message: message}
  defp warning(code, message), do: %Diagnostic{severity: :warning, code: code, message: message}
end
