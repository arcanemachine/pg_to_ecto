# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-09-26

### Changed

- Renamed the package, application, modules, Mix task, configuration, project paths, and managed markers from `pg_to_ecto`/`PgToEcto` to `postgres_to_ecto`/`PostgresToEcto`.
- No behavior, dependency, or capability expansion was added.

## [0.1.1] - 2026-09-26

### Changed

- The `pg_to_ecto` package has been renamed to `postgres_to_ecto`; users should migrate to `postgres_to_ecto` `0.1.2`.
- This patch changes documentation and release metadata only; runtime behavior and dependencies are unchanged. The replacement provides no compatibility aliases.

## [0.1.0] - 2026-09-26

### Added

- Explicit profile-based selection of PostgreSQL tables and Ecto modules.
- Read-only PostgreSQL catalog introspection for the supported table, column, key, foreign-key, referential-action, and index surface.
- Generated Ecto schemas and one regenerable baseline migration.
- Managed source regions, idempotent regeneration, dry-run behavior, force recovery, and preservation of user-owned source.
- Structured warnings for partial, omitted, or ambiguous mappings.
- Mix task and programmatic generation entry points.
- A synthetic disposable PostgreSQL demo and verification surface.
