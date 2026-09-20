defmodule PgToEcto.Introspection do
  @moduledoc false

  alias PgToEcto.Canonical

  @doc false
  @spec resolve_table(map() | String.t(), String.t() | nil) :: {:ok, map()} | {:error, atom()}
  def resolve_table(%{schema: schema, table: table} = selection, _default_prefix)
      when is_binary(schema) and is_binary(table) do
    with {:ok, schema} <- Canonical.normalize_identifier(schema),
         {:ok, table} <- Canonical.normalize_identifier(table) do
      {:ok, Map.put(selection, :schema, schema) |> Map.put(:table, table)}
    end
  end

  def resolve_table(name, default_prefix) when is_binary(name) do
    case PgToEcto.Profile.normalize_table_name(name, default_prefix || "public") do
      {:ok, identity} -> {:ok, identity}
      error -> error
    end
  end

  @doc false
  @spec resolve_tables([map() | String.t()], String.t() | nil) ::
          {:ok, [map()]} | {:error, atom()}
  def resolve_tables(selections, default_prefix) when is_list(selections) do
    Enum.reduce_while(selections, {:ok, []}, fn selection, {:ok, resolved} ->
      case resolve_table(selection, default_prefix) do
        {:ok, identity} -> {:cont, {:ok, resolved ++ [identity]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc false
  @spec introspect(module(), [map()]) :: {:ok, map()} | {:error, term()}
  def introspect(repo, selections) when is_atom(repo) and is_list(selections) do
    with :ok <- ensure_repo_available(repo) do
      run_catalog_queries(repo, selections)
    end
  end

  @doc false
  @spec introspect_profile(map()) :: {:ok, map()} | {:error, term()}
  def introspect_profile(%{repo: repo, tables: tables, migration_default_prefix: prefix}) do
    with {:ok, selections} <- resolve_tables(tables, prefix) do
      introspect(repo, selections)
    end
  end

  @doc false
  @spec normalize_catalog_result(Postgrex.Result.t()) :: [map()]
  def normalize_catalog_result(%Postgrex.Result{columns: columns, rows: rows}) do
    Enum.map(
      rows,
      &Map.new(Enum.zip(columns, &1), fn {key, value} -> {catalog_key(key), value} end)
    )
  end

  defp catalog_key(key) do
    case key do
      "server_version_num" -> :server_version_num
      "server_version" -> :server_version
      "schema" -> :schema
      "table" -> :table
      "relation_kind" -> :relation_kind
      "position" -> :position
      "name" -> :name
      "type_oid" -> :type_oid
      "type_schema" -> :type_schema
      "type_name" -> :type_name
      "type_modifier" -> :type_modifier
      "formatted_type" -> :formatted_type
      "not_null" -> :not_null
      "default_expression" -> :default_expression
      "serial_kind" -> :serial_kind
      "identity_kind" -> :identity_kind
      "owned_sequence" -> :owned_sequence
      "source_schema" -> :source_schema
      "source_table" -> :source_table
      "constraint_name" -> :constraint_name
      "kind" -> :kind
      "target_schema" -> :target_schema
      "target_table" -> :target_table
      "source_columns" -> :source_columns
      "target_columns" -> :target_columns
      "update_action" -> :update_action
      "delete_action" -> :delete_action
      "index_name" -> :index_name
      "is_unique" -> :is_unique
      "is_partial" -> :is_partial
      "is_expression" -> :is_expression
      "columns" -> :columns
      _ -> key
    end
  end

  defp run_catalog_queries(repo, selections) do
    schemas = Enum.map(selections, &Map.fetch!(&1, :schema))
    tables = Enum.map(selections, &Map.fetch!(&1, :table))

    with {:ok, server_result} <- query(repo, server_version_query(), []),
         {:ok, table_result} <- query(repo, table_query(), [schemas, tables]),
         {:ok, constraint_result} <- query(repo, constraint_query(), [schemas, tables]),
         {:ok, index_result} <- query(repo, index_query(), [schemas, tables]) do
      server = server_result |> normalize_catalog_result() |> List.first()
      table_rows = table_result |> normalize_catalog_result() |> normalize_table_rows()

      constraint_rows =
        constraint_result |> normalize_catalog_result() |> normalize_constraint_rows()

      index_rows = index_result |> normalize_catalog_result() |> normalize_index_rows()
      found = MapSet.new(table_rows, &{&1.schema, &1.table})
      missing = Enum.reject(selections, &MapSet.member?(found, {&1.schema, &1.table}))

      if missing == [] do
        {:ok, Canonical.assemble(server, table_rows, constraint_rows, index_rows, selections)}
      else
        {:error, {:missing_selected_tables, Enum.map(missing, &{&1.schema, &1.table})}}
      end
    end
  end

  defp query(repo, sql, params) do
    Ecto.Adapters.SQL.query(repo, sql, params, log: false, timeout: 15_000)
  end

  defp ensure_repo_available(repo) do
    if repo in Ecto.Repo.all_running() do
      :ok
    else
      {:error, {:repo_unavailable, repo}}
    end
  rescue
    _exception -> {:error, {:repo_unavailable, repo}}
  end

  defp normalize_table_rows(rows) do
    rows
    |> Enum.group_by(&{&1.schema, &1.table})
    |> Enum.map(fn {{schema, table}, table_rows} ->
      first = List.first(table_rows)

      columns =
        Enum.map(table_rows, fn row ->
          Map.take(row, [
            :name,
            :position,
            :type_oid,
            :type_schema,
            :type_name,
            :type_modifier,
            :formatted_type,
            :not_null,
            :default_expression,
            :serial_kind,
            :identity_kind,
            :owned_sequence
          ])
        end)

      %{
        schema: schema,
        table: table,
        relation_kind: first.relation_kind,
        columns:
          Enum.map(columns, fn column ->
            column
            |> Map.update(:serial_kind, nil, fn
              "bigserial" -> :bigserial
              value -> value
            end)
            |> Map.update(:identity_kind, nil, fn
              "" -> nil
              value -> value
            end)
          end)
      }
    end)
  end

  defp normalize_constraint_rows(rows) do
    Enum.map(rows, fn row ->
      kind =
        case row.kind do
          "p" -> :primary_key
          "f" -> :foreign_key
          "u" -> :unique
          value -> {:unknown, value}
        end

      %{
        name: row.constraint_name,
        kind: kind,
        source_identity: {row.source_schema, row.source_table},
        source_columns: row.source_columns || [],
        target_identity:
          if(row.target_schema && row.target_table,
            do: {row.target_schema, row.target_table},
            else: nil
          ),
        target_columns: row.target_columns || [],
        update_action: row.update_action,
        delete_action: row.delete_action,
        provenance: %{source: :pg_constraint, name: row.constraint_name}
      }
    end)
  end

  defp normalize_index_rows(rows) do
    Enum.map(rows, fn row ->
      %{
        name: row.index_name,
        source_identity: {row.source_schema, row.source_table},
        unique?: row.is_unique,
        columns: row.columns || [],
        expression?: row.is_expression,
        partial?: row.is_partial,
        provenance: %{source: :pg_index, name: row.index_name}
      }
    end)
  end

  defp server_version_query do
    """
    SELECT current_setting('server_version_num')::integer AS server_version_num,
           current_setting('server_version') AS server_version
    """
  end

  defp table_query do
    """
    WITH selected(schema_name, table_name) AS (
      SELECT * FROM unnest($1::text[], $2::text[])
    )
    SELECT ns.nspname AS schema,
           cls.relname AS table,
           cls.relkind::text AS relation_kind,
           att.attnum AS position,
           att.attname AS name,
           typ.oid::integer AS type_oid,
           type_ns.nspname AS type_schema,
           typ.typname AS type_name,
           att.atttypmod AS type_modifier,
           format_type(att.atttypid, att.atttypmod) AS formatted_type,
           att.attnotnull AS not_null,
           pg_get_expr(defaults.adbin, defaults.adrelid) AS default_expression,
           att.attidentity::text AS identity_kind,
           sequence_info.owned_sequence AS owned_sequence,
           CASE
             WHEN att.attidentity = ''
               AND typ.typname = 'int8'
               AND defaults.adbin IS NOT NULL
               AND left(btrim(pg_get_expr(defaults.adbin, defaults.adrelid)), 8) = 'nextval('
               AND sequence_info.owned_sequence IS NOT NULL
             THEN 'bigserial'
             ELSE NULL
           END AS serial_kind
    FROM selected
    JOIN pg_namespace AS ns ON ns.nspname = selected.schema_name
    JOIN pg_class AS cls ON cls.relnamespace = ns.oid AND cls.relname = selected.table_name
    JOIN pg_attribute AS att ON att.attrelid = cls.oid
    JOIN pg_type AS typ ON typ.oid = att.atttypid
    JOIN pg_namespace AS type_ns ON type_ns.oid = typ.typnamespace
    LEFT JOIN pg_attrdef AS defaults ON defaults.adrelid = cls.oid AND defaults.adnum = att.attnum
    LEFT JOIN LATERAL (
      SELECT pg_get_serial_sequence(
               format('%I.%I', ns.nspname, cls.relname),
               att.attname
             ) AS owned_sequence
    ) AS sequence_info ON true
    WHERE att.attnum > 0 AND NOT att.attisdropped
    ORDER BY ns.nspname, cls.relname, att.attnum
    """
  end

  defp constraint_query do
    """
    WITH selected(schema_name, table_name) AS (
      SELECT * FROM unnest($1::text[], $2::text[])
    )
    SELECT source_ns.nspname AS source_schema,
           source_cls.relname AS source_table,
           con.conname AS constraint_name,
           con.contype::text AS kind,
           target_ns.nspname AS target_schema,
           target_cls.relname AS target_table,
           ARRAY(
             SELECT source_att.attname
             FROM unnest(con.conkey) WITH ORDINALITY AS source_keys(attnum, ordinal)
             JOIN pg_attribute AS source_att
               ON source_att.attrelid = source_cls.oid
              AND source_att.attnum = source_keys.attnum
             ORDER BY source_keys.ordinal
           ) AS source_columns,
           ARRAY(
             SELECT target_att.attname
             FROM unnest(con.confkey) WITH ORDINALITY AS target_keys(attnum, ordinal)
             JOIN pg_attribute AS target_att
               ON target_att.attrelid = target_cls.oid
              AND target_att.attnum = target_keys.attnum
             ORDER BY target_keys.ordinal
           ) AS target_columns,
           con.confupdtype::text AS update_action,
           con.confdeltype::text AS delete_action
    FROM selected
    JOIN pg_namespace AS source_ns ON source_ns.nspname = selected.schema_name
    JOIN pg_class AS source_cls
      ON source_cls.relnamespace = source_ns.oid
     AND source_cls.relname = selected.table_name
    JOIN pg_constraint AS con ON con.conrelid = source_cls.oid
    LEFT JOIN pg_class AS target_cls ON target_cls.oid = con.confrelid
    LEFT JOIN pg_namespace AS target_ns ON target_ns.oid = target_cls.relnamespace
    WHERE con.contype IN ('p', 'f', 'u')
    ORDER BY source_ns.nspname, source_cls.relname, con.conname
    """
  end

  defp index_query do
    """
    WITH selected(schema_name, table_name) AS (
      SELECT * FROM unnest($1::text[], $2::text[])
    )
    SELECT source_ns.nspname AS source_schema,
           source_cls.relname AS source_table,
           index_cls.relname AS index_name,
           idx.indisunique AS is_unique,
           idx.indpred IS NOT NULL AS is_partial,
           idx.indexprs IS NOT NULL AS is_expression,
           ARRAY(
             SELECT attribute.attname
             FROM unnest(idx.indkey::smallint[]) WITH ORDINALITY AS keys(attnum, ordinal)
             JOIN pg_attribute AS attribute
               ON attribute.attrelid = source_cls.oid
              AND attribute.attnum = keys.attnum
             WHERE keys.ordinal <= idx.indnkeyatts
             ORDER BY keys.ordinal
           ) AS columns
    FROM selected
    JOIN pg_namespace AS source_ns ON source_ns.nspname = selected.schema_name
    JOIN pg_class AS source_cls
      ON source_cls.relnamespace = source_ns.oid
     AND source_cls.relname = selected.table_name
    JOIN pg_index AS idx ON idx.indrelid = source_cls.oid
    JOIN pg_class AS index_cls ON index_cls.oid = idx.indexrelid
    WHERE NOT idx.indisprimary
    ORDER BY source_ns.nspname, source_cls.relname, index_cls.relname
    """
  end
end
