defmodule PgToEctoDemo.SourceRepo.Migrations.Wave1Fixture do
  use Ecto.Migration

  def change do
    execute("CREATE SCHEMA IF NOT EXISTS internal", "DROP SCHEMA internal CASCADE")
    execute("CREATE SCHEMA IF NOT EXISTS sales", "DROP SCHEMA sales CASCADE")

    create table(:audit_events, prefix: "internal", primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :message, :text, null: false
    end

    create table(:customers, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :email, :text, null: false
      add :name, :text, null: false
      add :active, :boolean, null: false, default: true
      add :credit_limit, :integer, null: false, default: 0

      add :audit_event_id,
          references(:audit_events, prefix: "internal", on_delete: :nilify_all),
          null: true
    end

    create table(:orders, primary_key: false) do
      add :id, :bigserial, primary_key: true

      add :customer_id,
          references(:customers, on_delete: :delete_all, on_update: :nothing),
          null: false

      add :delete_restrict_customer_id,
          references(:customers, on_delete: :restrict, on_update: :update_all),
          null: true

      add :delete_nilify_customer_id,
          references(:customers, on_delete: :nilify_all, on_update: :restrict),
          null: true

      add :update_nilify_customer_id,
          references(:customers, on_delete: :nothing, on_update: :nilify_all),
          null: true

      add :external_ref, :text, null: false
      add :quantity, :integer, null: false, default: 1
      add :shipped, :boolean, null: false, default: false

      add :audit_event_id,
          references(:audit_events, prefix: "internal", on_delete: :nilify_all),
          null: true
    end

    create table(:invoices, prefix: "sales", primary_key: false) do
      add :id, :bigserial, primary_key: true

      add :customer_id,
          references(:customers, prefix: "public", on_delete: :delete_all),
          null: false

      add :code, :text, null: false
      add :amount, :integer, null: false, default: 0
    end

    create unique_index(:customers, [:email], name: :customers_email_index)
    create index(:orders, [:customer_id], name: :orders_customer_id_index)
    create unique_index(:orders, [:external_ref], name: :orders_external_ref_index)
    create index(:invoices, [:customer_id], prefix: "sales", name: :invoices_customer_id_index)
  end
end
