[
  import_deps: [:ecto, :ecto_sql],
  inputs: ["{mix,.formatter}.exs", "config/*.exs", "lib/**/*.ex", "test/**/*.exs"],
  locals_without_parens: [
    generated_settings: 1,
    generated_fields: 1,
    generated_change: 1
  ],
  export: [
    locals_without_parens: [
      generated_settings: 1,
      generated_fields: 1,
      generated_change: 1
    ]
  ]
]
