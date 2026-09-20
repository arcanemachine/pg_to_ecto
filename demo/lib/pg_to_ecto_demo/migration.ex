defmodule PgToEctoDemo.Repo.Migrations.Phase0 do
  use Ecto.Migration
  use PgToEcto.Migration

  def change do
    generated_change do
      create table(:widgets) do
        add :name, :text, null: false
      end
    end
  end
end
