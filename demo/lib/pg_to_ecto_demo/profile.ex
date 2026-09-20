defmodule PgToEctoDemo.Profile do
  use PgToEcto.Generator

  repo(PgToEctoDemo.SourceRepo)

  table("customers", module: PgToEctoDemo.Customer)
  table("orders", module: PgToEctoDemo.Order)
  table("sales.invoices", module: PgToEctoDemo.Invoice)
end
