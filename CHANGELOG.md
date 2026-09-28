# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-09-28

### Changed

- Removed obsolete release-status and migration guidance from public documentation.

## [0.1.2] - 2026-09-26

### Added

- Explicit profile-based selection of PostgreSQL tables and Ecto modules.
- Read-only PostgreSQL catalog introspection for the supported table, column, key, foreign-key, referential-action, and index surface.
- Generated Ecto schemas and one regenerable baseline migration.
- Managed source regions, idempotent regeneration, dry-run behavior, force recovery, and preservation of user-owned source.
- Structured warnings for partial, omitted, or ambiguous mappings.
- Mix task and programmatic generation entry points.
- A synthetic disposable PostgreSQL demo and verification surface.
