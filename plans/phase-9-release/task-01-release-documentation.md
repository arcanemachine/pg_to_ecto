# Task 9.1: Finalize `0.1.0` Release Documentation

## Status

Complete and verified; user acceptance approved. Architecture acceptance is pending under the Phase 9 release gate.

## Owner

Worker

## Coordinator and reporting route

Sergeant is the coordinator under the standard coordinated route. Report questions, blockers, completion evidence, and process feedback only to Sergeant unless the user explicitly reroutes the task.

## Objective

Convert the accepted `0.1.0` candidate wording into accurate final release documentation without changing product behavior, package dependencies, supported runtimes, or capability claims.

## Required reading

Read only:

1. `AGENTS.md` — project safety, verification, documentation, and release rules.
2. `plans/phase-9-release/README.md` — accepted release scope, wording boundaries, gates, and sequence.
3. `README.md` — public status, installation guidance, behavior, ownership contract, and capability matrix.
4. `CHANGELOG.md` — candidate release notes to finalize.
5. `mix.exs` — read only to verify the target version and existing package metadata.

Do not read `PLAN.md`; lifecycle coordination belongs to Sergeant and Architect.

## Allowed files

- `README.md`
- `CHANGELOG.md`

No other file may be edited. In particular, do not edit `mix.exs`: it already declares the accepted target version. Report any mismatch instead.

## Required changes

### `README.md`

Replace only the pre-release status statement with evergreen release wording that:

- identifies `0.1.0` as the current initial Wave 1 release;
- does not imply Wave 2 capabilities;
- remains accurate after publication rather than describing a candidate or future action.

Keep the dependency requirement `~> 0.1.0` unchanged. Do not rewrite setup, generator usage, ownership, safety, capability-matrix, demo, or development guidance unless a direct contradiction prevents truthful release status wording. Report such a contradiction instead of expanding scope.

Replace the final paragraph's candidate-oriented release-readiness wording with an evergreen boundary statement. It must continue to say that the document describes the verified Wave 1 behavior and must not imply that deferred capabilities are included.

Fix obvious documentation defects in the allowed files when a required check exposes them and the correction preserves established meaning, behavior, and scope. Keep such corrections narrow and continue without escalation. Stop only when a correction requires a new public claim, package change, product decision, or edit outside the allowed files.

### `CHANGELOG.md`

Use the established release structure:

```text
# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog 1.1.0,
and this project adheres to Semantic Versioning 2.0.0.

## [0.1.0] - YYYY-MM-DD

### Added
...
```

Use Markdown links for Keep a Changelog and Semantic Versioning. Replace `YYYY-MM-DD` with the actual release date supplied or confirmed by Sergeant; do not guess a future date.

The `Added` section must concisely preserve the accepted candidate evidence and cover these user-visible areas without claiming deferred behavior:

- explicit profile-based PostgreSQL table and Ecto-module selection;
- read-only catalog introspection and the supported Wave 1 table, column, key, foreign-key, referential-action, and index surface;
- generated schemas plus one regenerable baseline migration;
- managed source regions, idempotent regeneration, dry-run behavior, force recovery, and user-owned source preservation;
- structured warnings for partial, omitted, or ambiguous mappings;
- Mix task and programmatic generation entry points;
- the synthetic disposable PostgreSQL demo and verification surface.

Keep unsupported and deferred capabilities out of the `Added` list. Do not advertise historical migration reconstruction, automatic association or changeset generation, composite keys, UUIDs, decimals, arrays, advanced indexes, checks, generated columns, PostgreSQL-native objects, or any other deferred feature.

Remove the candidate-only sentence stating that publication and release remain gated. The changelog included in the final archive describes the release itself; lifecycle gates remain in `PLAN.md`, the phase plan, and `AGENTS.md`.

## Authorized scope correction

Architect authorized one narrow documentation correction for the required warning-free `mix docs` gate: replace only the unresolved Markdown directory link ``[`demo/`](demo/)`` with inline code `` `demo/` `` while preserving the surrounding sentence. Do not add demo files to the Hex package, change warning policy, or suppress warnings. This correction does not change user-facing or product scope.

## Non-goals

- No code, tests, package metadata, dependencies, runtime requirements, generator behavior, CLI output, or generated output changes.
- No capability expansion or release automation.
- No GitHub Release notes or assets.
- No changes to already-published changelog entries. This is the first entry and is not yet published.
- No coordination-state edits.

## Focused verification

Run from the project root:

```text
mix format --check-formatted
mix docs
git diff --check
```

Treat every documentation warning as a failure. Do not run database-dependent verification; Sergeant owns the complete release gate after task review.

Confirm manually that:

- every occurrence of the package version in `mix.exs`, `README.md`, and the new changelog heading is `0.1.0`;
- the README no longer describes the package as pre-release;
- the changelog no longer describes `0.1.0` as a candidate;
- the diff changes only `README.md` and `CHANGELOG.md`;
- no generated documentation or archive remains in the working tree.

## Stop conditions

Stop and report to Sergeant if:

- no actual release date has been established;
- accurate wording appears to require a capability, dependency, runtime, package metadata, or code change;
- the existing README and accepted release evidence conflict materially;
- `mix docs` fails or warns for reasons outside the two allowed files;
- another session changes an allowed file during the task;
- the working tree contains unrelated changes that prevent isolating this task.

## Completion report

Report:

- changed files;
- the final release-status and changelog structure in summary, without pasting entire files;
- focused command outcomes and warning status;
- confirmation that version references agree;
- confirmation that only allowed files changed and no artifacts remain;
- any process feedback or `none`.

Do not commit, tag, push, or publish.
