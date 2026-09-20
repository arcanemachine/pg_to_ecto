defmodule PgToEctoDemo.Widget do
  use Ecto.Schema
  use PgToEcto.Schema

  generated_settings do
    @primary_key false
  end

  schema "widgets" do
    generated_fields do
      field :id, :id, primary_key: true
      field :name, :string
    end

    field :display_name, :string, virtual: true
  end
end
