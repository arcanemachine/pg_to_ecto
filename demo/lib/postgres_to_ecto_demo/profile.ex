defmodule PostgresToEctoDemo.Profile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoDemo.SourceRepo)

  table("customers", module: PostgresToEctoDemo.Customer)
  table("orders", module: PostgresToEctoDemo.Order)
  table("sales.invoices", module: PostgresToEctoDemo.Invoice)
end
