defmodule PostgresToEcto.Canonical do
  @moduledoc false

  @type mapping_disposition :: :exact | :approximated | :omitted_with_warning | :blocking

  @doc false
  @spec normalize_identifier(term()) :: {:ok, String.t()} | {:error, atom()}
  def normalize_identifier(value) when is_binary(value) do
    if value != "" and not String.contains?(value, <<0>>) do
      {:ok, value}
    else
      {:error, :invalid_identifier}
    end
  end

  def normalize_identifier(_value), do: {:error, :invalid_identifier}

  @doc false
  @spec normalize_type(map()) :: map()
  def normalize_type(row) when is_map(row) do
    type_name = Map.get(row, :type_name, Map.get(row, "type_name"))
    type_schema = Map.get(row, :type_schema, Map.get(row, "type_schema"))

    type_identity = %{
      oid: Map.get(row, :type_oid, Map.get(row, "type_oid")),
      schema: type_schema,
      name: type_name,
      modifier: Map.get(row, :type_modifier, Map.get(row, "type_modifier")),
      formatted: Map.get(row, :formatted_type, Map.get(row, "formatted_type"))
    }

    case type_name do
      "text" ->
        %{postgres: type_identity, schema: :string, migration: :text, disposition: :approximated}

      name when name in ["varchar", "bpchar", "int2"] ->
        %{postgres: type_identity, schema: nil, migration: nil, disposition: :blocking}

      "int4" ->
        %{postgres: type_identity, schema: :integer, migration: :integer, disposition: :exact}

      "int8" ->
        %{
          postgres: type_identity,
          schema: :integer,
          migration: :bigint,
          disposition: :approximated
        }

      name when name in ["bool", "boolean"] ->
        %{postgres: type_identity, schema: :boolean, migration: :boolean, disposition: :exact}

      _ ->
        %{postgres: type_identity, schema: nil, migration: nil, disposition: :blocking}
    end
  end

  @doc false
  @spec normalize_default(nil | String.t()) :: map()
  def normalize_default(nil), do: %{expression: nil, classification: :none, value: nil}

  def normalize_default(expression) when is_binary(expression) do
    trimmed = String.trim(expression)

    cond do
      trimmed in ["true", "false"] ->
        %{
          expression: expression,
          classification: :safe_literal,
          value: trimmed == "true",
          type: :boolean
        }

      Regex.match?(~r/\A-?\d+\z/, trimmed) ->
        %{
          expression: expression,
          classification: :safe_literal,
          value: String.to_integer(trimmed),
          type: :integer
        }

      true ->
        classify_quoted_default(expression, trimmed)
    end
  end

  def normalize_default(_expression), do: %{expression: nil, classification: :none, value: nil}

  @doc false
  @spec normalize_action(String.t() | atom() | nil) :: atom()
  def normalize_action(action) when action in ["a", :a, "NO ACTION", :no_action], do: :no_action
  def normalize_action(action) when action in ["r", :r, "RESTRICT", :restrict], do: :restrict
  def normalize_action(action) when action in ["c", :c, "CASCADE", :cascade], do: :cascade
  def normalize_action(action) when action in ["n", :n, "SET NULL", :set_null], do: :set_null

  def normalize_action(action) when action in ["d", :d, "SET DEFAULT", :set_default],
    do: :set_default

  def normalize_action(_action), do: :unknown

  @doc false
  @spec assemble(map(), [map()], [map()], [map()], [map()]) :: map()
  def assemble(server, table_rows, constraint_rows, index_rows, selected_tables) do
    selected_identities = MapSet.new(selected_tables, &identity/1)
    table_rows_by_identity = Map.new(table_rows, &{identity(&1), &1})

    tables =
      selected_tables
      |> Enum.map(fn selected ->
        table_identity = identity(selected)
        row = Map.get(table_rows_by_identity, table_identity, selected)

        build_table(
          row,
          table_identity,
          constraint_rows,
          index_rows,
          selected_identities,
          selected
        )
      end)

    %{
      server_version: server,
      tables: tables,
      selected_tables: Enum.map(selected_tables, &identity/1),
      provenance: %{source: :postgres_catalog}
    }
  end

  @doc false
  @spec identity(map()) :: {String.t(), String.t()}
  def identity(row), do: {Map.fetch!(row, :schema), Map.fetch!(row, :table)}

  defp build_table(
         row,
         table_identity,
         constraint_rows,
         index_rows,
         selected_identities,
         selection
       ) do
    constraints = Enum.filter(constraint_rows, &(Map.get(&1, :source_identity) == table_identity))

    primary_key =
      constraints
      |> Enum.find_value([], fn constraint ->
        if Map.get(constraint, :kind) == :primary_key,
          do: Map.get(constraint, :source_columns, [])
      end)

    columns =
      row
      |> Map.get(:columns, [])
      |> Enum.sort_by(&Map.get(&1, :position, 0))
      |> Enum.map(fn column ->
        Map.put(column, :primary_key?, Map.fetch!(column, :name) in primary_key)
      end)
      |> Enum.map(&build_column/1)

    foreign_keys =
      constraints
      |> Enum.filter(&(Map.get(&1, :kind) == :foreign_key))
      |> Enum.map(fn constraint ->
        target_identity = Map.get(constraint, :target_identity)
        selected_target? = MapSet.member?(selected_identities, target_identity)

        Map.merge(constraint, %{
          update_action: normalize_action(Map.get(constraint, :update_action)),
          delete_action: normalize_action(Map.get(constraint, :delete_action)),
          mapping_disposition: if(selected_target?, do: :exact, else: :omitted_with_warning),
          selected_target?: selected_target?
        })
      end)

    indexes =
      index_rows
      |> Enum.filter(&(Map.get(&1, :source_identity) == table_identity))
      |> Enum.map(fn index ->
        columns = Map.get(index, :columns, [])

        supported? =
          columns != [] and Map.get(index, :expression?, false) == false and
            Map.get(index, :partial?, false) == false

        Map.put(
          index,
          :mapping_disposition,
          if(supported?, do: :exact, else: :omitted_with_warning)
        )
      end)

    %{
      identity: %{schema: elem(table_identity, 0), table: elem(table_identity, 1)},
      selection: Map.take(selection, [:module, :file, :source_name, :overrides]),
      relation_kind: relation_kind(Map.get(row, :relation_kind)),
      columns: columns,
      primary_key: primary_key,
      foreign_keys: foreign_keys,
      indexes: indexes,
      provenance: %{source: :postgres_catalog, identity: table_identity},
      mapping_disposition: table_mapping_disposition(row, columns)
    }
  end

  defp build_column(column) do
    type = normalize_type(column)
    default = normalize_default(Map.get(column, :default_expression))
    serial_kind = Map.get(column, :serial_kind)
    owned_sequence = Map.get(column, :owned_sequence)
    identity_code = Map.get(column, :identity_kind) || Map.get(column, :identity)
    identity = normalize_identity(identity_code)

    mapping =
      cond do
        identity != nil ->
          %{schema: type.schema, migration: type.migration, disposition: :blocking}

        serial_kind == :bigserial and Map.get(column, :primary_key?, false) and
            active_serial_default?(default.expression) ->
          %{schema: :id, migration: :bigserial, disposition: :exact}

        serial_kind == :bigserial ->
          %{schema: type.schema, migration: type.migration, disposition: :blocking}

        owned_sequence != nil ->
          %{schema: type.schema, migration: type.migration, disposition: :blocking}

        true ->
          %{schema: type.schema, migration: type.migration, disposition: type.disposition}
      end

    %{
      name: Map.fetch!(column, :name),
      position: Map.get(column, :position),
      type: type,
      serial_kind: serial_kind,
      owned_sequence: owned_sequence,
      identity: identity,
      identity_code: identity_code,
      nullable: not Map.get(column, :not_null, false),
      default_expression: default.expression,
      default: default,
      mapping: mapping,
      provenance: %{source: :postgres_catalog, column: Map.fetch!(column, :name)}
    }
  end

  defp active_serial_default?(expression) when is_binary(expression) do
    String.starts_with?(String.trim(expression), "nextval(")
  end

  defp active_serial_default?(_expression), do: false

  defp normalize_identity(nil), do: nil
  defp normalize_identity(""), do: nil
  defp normalize_identity("a"), do: :always
  defp normalize_identity("d"), do: :by_default
  defp normalize_identity(value) when value in [:always, :by_default], do: value
  defp normalize_identity(value), do: {:unknown, value}

  defp relation_kind("r"), do: :table
  defp relation_kind("p"), do: :partitioned_table
  defp relation_kind("v"), do: :view
  defp relation_kind("m"), do: :materialized_view
  defp relation_kind("f"), do: :foreign_table
  defp relation_kind(value), do: {:unknown, value}

  defp table_mapping_disposition(row, columns) do
    cond do
      Map.get(row, :relation_kind) != "r" ->
        :blocking

      Enum.any?(columns, fn column ->
        get_in(column, [:mapping, :disposition]) == :blocking
      end) ->
        :blocking

      true ->
        :exact
    end
  end

  defp classify_quoted_default(expression, trimmed) do
    case parse_sql_string(trimmed) do
      {:ok, value, nil} ->
        %{expression: expression, classification: :safe_literal, value: value, type: :string}

      {:ok, value, cast} ->
        classify_cast_default(expression, value, cast)

      :error ->
        %{expression: expression, classification: :database_expression, value: nil}
    end
  end

  defp classify_cast_default(expression, value, cast) do
    case normalize_cast_type(cast) do
      :boolean when value in ["true", "false"] ->
        %{
          expression: expression,
          classification: :safe_literal,
          value: value == "true",
          type: :boolean
        }

      :integer when is_binary(value) ->
        if Regex.match?(~r/\A-?\d+\z/, value) do
          %{
            expression: expression,
            classification: :safe_literal,
            value: String.to_integer(value),
            type: :integer
          }
        else
          %{expression: expression, classification: :database_expression, value: nil}
        end

      :string ->
        %{expression: expression, classification: :safe_literal, value: value, type: :string}

      _ ->
        %{expression: expression, classification: :database_expression, value: nil}
    end
  end

  defp normalize_cast_type(cast) do
    normalized =
      cast
      |> String.replace("\"", "")
      |> String.downcase()
      |> String.trim()

    {schema, type_name} =
      case String.split(normalized, ".") do
        [name] -> {nil, name}
        [schema, name] -> {schema, name}
        _ -> {:invalid, normalized}
      end

    if schema not in [nil, "pg_catalog"] do
      :unknown
    else
      case type_name do
        "character varying" ->
          :string

        "character" ->
          :string

        name when name in ["bool", "boolean"] ->
          :boolean

        name when name in ["int2", "smallint", "int4", "integer", "int", "int8", "bigint"] ->
          :integer

        name when name in ["text", "varchar", "char", "bpchar"] ->
          :string

        _ ->
          :unknown
      end
    end
  end

  defp parse_sql_string(value) do
    case Regex.run(
           ~r/\A'((?:[^']|'')*)'(?:\s*::\s*([[:alnum:]_.\"]+(?:\s+[[:alnum:]_.\"]+)*))?\z/,
           value,
           capture: :all_but_first
         ) do
      [inner, nil] -> {:ok, String.replace(inner, "''", "'"), nil}
      [inner, cast] -> {:ok, String.replace(inner, "''", "'"), String.trim(cast)}
      _ -> :error
    end
  end
end
