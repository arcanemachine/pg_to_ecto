# Phase 10: `pg_to_ecto` Retirement and `postgres_to_ecto` Rename

## Lifecycle status

- Planning status: Complete and execution-ready
- Execution status: Both local release boundaries complete; user-owned remote sequence pending
- Current owner: User, for repository rename, pushes, publications, and old-version retirement
- Selected execution route: Architect-direct coordination
- Old-package release: `pg_to_ecto` `0.1.1`, no-code retirement patch
- Renamed release: `postgres_to_ecto` `0.1.2`, direct in-place rename
- Compatibility posture: No aliases, dual tasks, dual configuration, or automatic old-format handling
- Public authority: Repository rename, pushes, Hex publication, Hex retirement, and credentials remain user-owned

## Purpose

Retire the published `pg_to_ecto` name cleanly and continue the same project's version history under `postgres_to_ecto` without inventing a second product or resetting versions.

The phase produces two consecutive patch releases from one repository history:

1. `pg_to_ecto` `0.1.1` changes no runtime code. It updates package metadata, README, HexDocs-facing content, and the changelog to state that the package has been renamed to `postgres_to_ecto`.
2. `postgres_to_ecto` `0.1.2` mechanically renames the package, application, modules, Mix task, configuration, managed markers, files, directories, demo, tests, and documentation from `pg`/`Pg` to `postgres`/`Postgres` while preserving the accepted Wave 1 behavior.

The old `0.1.1` retirement package is published only after `postgres_to_ecto` `0.1.2` is publicly available and verified, so every retirement link and instruction has a valid destination. Hex versions `pg_to_ecto` `0.1.0` and `0.1.1` are then marked retired with reason `renamed`. The latest old-package HexDocs remains the durable migration notice.

This is a breaking namespace rename, not a compatibility layer. Existing users receive explicit mechanical migration instructions; the renamed implementation does not retain or recognize old public APIs.

## Present facts

- `pg_to_ecto` `0.1.0` has been reported as published on Hex. Exact package and HexDocs verification must be repeated before release work changes public state.
- The accepted `0.1.0` release commit is `6b7eac4` with lightweight tag `v0.1.0`. Commit `0423a22` records the subsequent publication handoff.
- The local `pg_to_ecto` `0.1.1` release commit is `5b7bb22`, and lightweight tag `v0.1.1` points exactly to it.
- The checkout has been renamed to `/workspace/projects/postgres_to_ecto`; its remote remains `git@github.com:arcanemachine/pg_to_ecto.git` until the user-owned remote repository rename.
- The current application/package is `postgres_to_ecto` `0.1.2`. Task 10.2 renamed package metadata, application configuration, library modules, Mix task names, paths, tests, demo code, generated output, managed markers, diagnostics, documentation, and process guidance.
- The renamed release passed architecture acceptance with no blocking findings. The exact package archive checksum is `2c0068b3e90f74554eb0e5d6339e5f4f895a9fe7b08effcfe25db60df7f8129f`.
- The managed-output attribute is `@pg_to_ecto_key`; valid values begin with `pgte1:`. The key payload is derived from the target module and managed regions. A mechanical change to `@postgres_to_ecto_key` and `postgreste1:` can preserve the existing payload after users update their files, but the renamed generator will not parse the old attribute or prefix.
- Generated documentation and package archives have been removed. The release commit contains only intended tracked source, documentation, test, demo, and coordination changes.
- Coordination-document centralization under `/workspace/projects/_plans` remains separate from this phase because its stale modified destination requires its own resolved migration route.

## User-approved decisions

1. Keep one repository history and continue the version sequence.
2. Publish a no-code `pg_to_ecto` `0.1.1` retirement patch before completing the rename history.
3. Release the renamed package as `postgres_to_ecto` `0.1.2`.
4. Rename `pg_to_ecto` to `postgres_to_ecto` and `PgToEcto` to `PostgresToEcto`, including corresponding files, directories, package metadata, tasks, configuration, managed markers, demo surfaces, tests, and documentation.
5. Keep `v0.1.0` as the historical first release, tag the retirement patch `v0.1.1`, and tag the renamed release `v0.1.2`.
6. Add no compatibility aliases, old-name modules, old-name Mix tasks, dual application configuration, or automatic migration layer.
7. Preserve accepted Wave 1 behavior and capability boundaries. This phase adds no generator capabilities and changes no dependencies or supported runtimes.
8. Publish and verify `postgres_to_ecto` `0.1.2` before publishing the old package's `0.1.1` retirement patch.
9. After both packages are public, retire `pg_to_ecto` `0.1.0` and `0.1.1` with Hex reason `renamed` and a concise message naming `postgres_to_ecto`.
10. Keep irreversible remote actions and credentials user-owned.

## Scope

### Included

- Prepare `pg_to_ecto` `0.1.1` as a no-code retirement release.
- Update the old package's version, description, README status and migration notice, and changelog without changing `lib/`, dependencies, runtime behavior, generated output, task behavior, demo behavior, or tests.
- Build and inspect the old package archive and render its HexDocs-facing content.
- Obtain user and architecture acceptance for the exact old-package retirement candidate, then create `chore: release v0.1.1` and lightweight tag `v0.1.1` under the approved route.
- Rename the local checkout directory from `/workspace/projects/pg_to_ecto` to `/workspace/projects/postgres_to_ecto` after the old release commit and tag exist.
- Rename package/application identifiers, modules, tasks, configuration, paths, files, directories, managed markers, diagnostic text, public documentation, process guidance, tests, demo application, disposable database naming family, and checked-in generated fixtures.
- Set the renamed package version to `0.1.2`; retain the existing changelog history and add the rename entry.
- Add direct user migration instructions for dependency, formatter import, application config, profile modules, programmatic API, Mix task, managed `use` lines, managed marker attribute/prefix, generated comments, and any project-local file paths.
- Verify that manually applying the documented textual rename to a valid old generated file produces a valid new-format managed file without changing user-owned source around managed regions.
- Run complete root, docs, disposable-demo, rename-audit, artifact-cleanliness, and exact-package checks.
- Obtain user and architecture acceptance for the exact renamed release, then create `chore: release v0.1.2` and lightweight tag `v0.1.2` under the approved route.
- Prepare the exact user-owned repository rename, push, Hex publication, and retirement commands.
- Verify both public packages, HexDocs surfaces, source link, tags, retirement messages, and installation guidance without credentials.

### Excluded

- Wave 2 capabilities or any behavior/API change unrelated to the rename.
- Dependency, Elixir, Ecto, PostgreSQL, packaging-tool, or release-automation changes.
- Compatibility aliases, old-name modules, old-name Mix tasks, dual configuration keys, automatic old-marker parsing, or silent migration of old generated files.
- A second repository lineage, version reset, GitHub Release, or separate announcement channel.
- Rewriting the published `pg_to_ecto` `0.1.0` package, changelog entry, tag, or source history.
- Agent-performed remote repository rename, Git push, Hex publication, Hex retirement, credential handling, or other irreversible remote action.
- Coordination-document centralization under `/workspace/projects/_plans`.

## Authoritative surfaces

- `mix.exs` owns the active package/application name, version, dependency set, package description, source/homepage links, docs configuration, and package file list.
- `README.md` owns package status, installation, setup, generation, migration guidance, safety, capability claims, and demo/development instructions.
- `CHANGELOG.md` owns versioned user-facing history. The published `0.1.0` entry remains unchanged; `0.1.1` records retirement and `0.1.2` records the rename.
- `lib/` owns public/internal modules, generated-source helpers, managed marker grammar, diagnostics, and the Mix task.
- `test/` owns deterministic root behavior, rename, and managed-source safety evidence.
- `demo/` owns the disposable consumer, configuration, lifecycle naming rules, source fixture, generated outputs, migration, and real-PostgreSQL acceptance surface.
- `AGENTS.md` and `.agents/roles/*.md` own durable project identity, safety, coordination, release, and verification guidance.
- `PLAN.md` owns current lifecycle status and pointers. This phase README owns sequence, boundaries, gates, and completion criteria. Task packets own executable assignments.

## Task sequence

The approved Architect-direct route authorizes Architect to commit this reset-safe planning handoff, dispatch each ready task to a fresh Worker, review and return routine corrections, run or confirm the stated verification, sequence the local checkout rename, and create the local release commits and lightweight tags after their acceptance gates. No per-task confirmation is required. Remote repository changes, pushes, Hex publication, retirement, and credentials remain user-owned.

### Task 10.1 — Prepare `pg_to_ecto` `0.1.1` retirement patch

Packet: `plans/phase-10-package-rename/task-01-retirement-patch.md`

One Worker changes only `mix.exs`, `README.md`, and `CHANGELOG.md`. Runtime source, dependencies, tests, demo, generated fixtures, and coordination files remain unchanged.

The candidate must:

- set version `0.1.1`;
- describe `pg_to_ecto` as renamed and direct users to `postgres_to_ecto` `0.1.2`;
- retain enough old-package usage context to identify what is being replaced, while placing the retirement notice before normal usage guidance;
- add an immutable-style `0.1.1` changelog entry recording the rename and migration destination;
- keep the `0.1.0` changelog entry byte-for-byte unchanged;
- change no behavior or dependency metadata.

Sergeant reviews the diff, runs the task checks and the complete old-package release gates, inspects the exact archive, and presents one user acceptance gate for the old retirement release. Architect then performs the bounded architecture acceptance required before the old local release commit/tag.

After both acceptances, the approved route authorizes:

- release commit `chore: release v0.1.1`;
- lightweight tag `v0.1.1` pointing exactly to that commit;
- no push or publication.

### Coordinator transition — Rename the local checkout root

After `v0.1.1` exists locally, the coordinator:

1. confirms the working tree is clean;
2. confirms no active Worker is bound to the old path;
3. renames `/workspace/projects/pg_to_ecto` to `/workspace/projects/postgres_to_ecto`;
4. verifies the Git repository, branch, tags, and remote configuration survived unchanged;
5. updates durable coordination paths before dispatching Task 10.2;
6. dispatches a fresh Worker whose assignment is rooted at `/workspace/projects/postgres_to_ecto`.

This is a local filesystem rename, not the user-owned remote GitHub repository rename.

### Task 10.2 — Rename implementation to `postgres_to_ecto` `0.1.2`

Packet: `plans/phase-10-package-rename/task-02-in-place-rename.md`

A fresh Worker performs the direct rename across all allowed source, test, demo, generated-fixture, documentation, package, and role-guidance surfaces. It does not edit `PLAN.md` or phase/task packets.

The task must:

- set package/application/version to `postgres_to_ecto` `0.1.2`;
- rename `PgToEcto` modules to `PostgresToEcto` and rename their source/test paths;
- rename `mix pg_to_ecto.generate` to `mix postgres_to_ecto.generate` and its task module/file/tests;
- rename application configuration and formatter imports;
- rename demo application/modules/paths/database family while retaining the disposable-name guard;
- rename `@pg_to_ecto_key` to `@postgres_to_ecto_key` and `pgte1:` to `postgreste1:` without retaining old parsers;
- update generated comments, temporary-file prefixes, output names, diagnostics, docs, tests, and checked-in canonical outputs;
- update source/homepage URLs to the intended renamed GitHub path, while publication remains blocked until the user confirms the remote rename exists;
- add precise breaking-migration instructions;
- preserve behavior, dependencies, runtime support, source authority, read-only introspection, and user-owned-source safety.

Sergeant reviews, corrects routine in-scope issues through the established task route, runs the full gates, inspects the exact archive, and presents one user acceptance gate for the renamed release. Architect then performs bounded architecture acceptance.

After both acceptances, the approved route authorizes:

- release commit `chore: release v0.1.2`;
- lightweight tag `v0.1.2` pointing exactly to that commit;
- no remote rename, push, publication, or retirement.

## Verification

### Task 10.1 focused checks

From the old project root:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix docs
git diff --check
mix hex.build
```

Inspect the exact `pg_to_ecto-0.1.1.tar` metadata, dependencies, description, file list, README, changelog, and checksum. Confirm `lib/`, dependencies, demo, tests, generated fixtures, and the `0.1.0` changelog entry did not change. Remove `doc/` and the archive after evidence is recorded.

### Task 10.2 focused and full checks

From `/workspace/projects/postgres_to_ecto`:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix docs
git diff --check
mix hex.build
```

From `demo/`, with the documented disposable PostgreSQL source and target and required non-empty `POSTGRES_PASSWORD`:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Verification must also confirm:

- all root and demo tests pass without warnings;
- canonical generated outputs are stable after regeneration and byte/mode restoration checks;
- source introspection remains read-only;
- disposable database commands reject names outside the renamed safe family;
- manually renamed old generated files validate under the new marker without changing user-owned source;
- no old executable/package/demo/test identifier remains;
- remaining old names appear only in historical changelog entries and explicit migration/retirement guidance;
- `postgres_to_ecto-0.1.2.tar` contains only intended package files and no tests, demo, plans, credentials, build output, or old compatibility surface;
- generated `doc/`, archives, temporary databases/files, and other runtime artifacts are removed;
- the working tree contains only intended tracked changes before each acceptance gate.

## User acceptance surfaces

The user approved the complete plan and explicitly instructed Architect to execute uninterrupted through both local release-ready states, then provide final remote push/publication instructions. This is a user-initiated waiver of separate intermediate acceptance prompts. Routine task dispatch, corrections, checks, integration mechanics, acceptance recording, commits, tags, and in-plan sequencing proceed without further permission requests. The final report must still present the exact evidence and commands the user needs before performing irreversible remote actions.

### Waived intermediate gate 1 — Old-package retirement release

Present:

- exact `0.1.1` diff;
- prominent README/HexDocs retirement wording;
- unchanged runtime/dependency evidence;
- root verification results;
- archive metadata, complete file list, and checksum;
- proposed local release commit/tag;
- confirmation that publication is intentionally deferred until the replacement exists.

### Waived intermediate gate 2 — Renamed release

Present:

- exact rename and migration-documentation diff summary;
- full root and disposable-PostgreSQL outcomes;
- rename audit and user-owned-source preservation evidence;
- archive metadata, complete file list, and checksum;
- source-link/remote-rename readiness;
- proposed local release commit/tag;
- exact remaining user-owned public steps.

Automated checks do not replace architecture review. Any blocking finding returns only the affected task for same-task correction when possible. The user's waiver removes repeated conversational approval prompts; it does not lower verification, archive inspection, architecture-acceptance, or remote-authority requirements.

## User-owned public sequence

After both local release commits/tags exist and both acceptance gates pass:

1. Rename the public repository from `pg_to_ecto` to `postgres_to_ecto` and update the local `origin` URL if Git does not preserve the expected destination automatically.
2. Push the accepted branch and lightweight tags `v0.1.1` and `v0.1.2`.
3. Publish `postgres_to_ecto` `0.1.2` from the exact `v0.1.2` source state.
4. Verify the new Hex package, HexDocs, checksum where available, source link, and installation guidance.
5. Publish `pg_to_ecto` `0.1.1` from the exact `v0.1.1` source state. The coordinator may prepare non-credential checkout instructions, but the user performs publication.
6. Verify that `https://hexdocs.pm/pg_to_ecto` resolves to the `0.1.1` retirement documentation and links to the live replacement.
7. Retire both old versions:

   ```text
   mix hex.retire pg_to_ecto 0.1.0 renamed --message "Renamed to postgres_to_ecto; install postgres_to_ecto instead."
   mix hex.retire pg_to_ecto 0.1.1 renamed --message "Renamed to postgres_to_ecto; install postgres_to_ecto instead."
   ```

8. Report completion without sharing credentials or sensitive output.

Agents must not perform these remote or credential-bearing actions without separate explicit authority. A partial public success is a blocker; preserve state and recover forward rather than rewriting published history.

## Architecture acceptance

For each release candidate, Architect performs a bounded sanity pass after Sergeant verification and user acceptance.

For `0.1.1`, confirm:

- runtime source and dependencies are unchanged;
- package metadata and docs accurately describe retirement;
- the old package points to the exact replacement name/version;
- the archive remains a valid old package rather than a compatibility shim or renamed implementation;
- public publication is still deferred until the replacement exists.

For `0.1.2`, confirm:

- the rename is complete and direct;
- no compatibility aliases or old executable surfaces remain;
- behavior, dependencies, capability claims, source authority, and safety boundaries are unchanged;
- migration guidance is sufficient and does not tell users to force-overwrite mixed-ownership files;
- package contents, full verification, real PostgreSQL evidence, source link, version, and user acceptance are complete;
- remote actions remain user-owned.

Architecture acceptance reports findings and waits for the user before recording acceptance, as required by the project lifecycle. Once accepted, local release commit/tag mechanics continue without another redundant approval.

## Stop conditions

Stop and return to Architect or the user if:

- either release requires runtime code changes outside the approved direct rename;
- dependencies, supported runtimes, capabilities, APIs beyond naming, database behavior, or packaging tools would change;
- old-package `0.1.1` modifies `lib/`, runtime dependencies, demo behavior, generated fixtures, or the published `0.1.0` changelog entry;
- old aliases, dual tasks, dual config, or automatic old-marker handling appear in `0.1.2`;
- migration instructions would require force-overwriting user-owned source;
- the local root cannot be renamed safely because another owner is active there;
- the intended `postgres_to_ecto` Hex name or remote repository destination is unavailable;
- source URLs would be published before the renamed remote exists;
- any required check fails, warns, changes canonical output unexpectedly, or leaves artifacts;
- either archive contains credentials, coordination plans, unintended files, or the wrong namespace;
- a required user or architecture acceptance is missing;
- an agent would need credentials or authority for repository rename, push, publication, or retirement;
- public publication partially succeeds and the recovery route is not explicit.

## Completion criteria

Phase 10 is complete only when:

- `pg_to_ecto` `0.1.1` is a verified no-code retirement release with default HexDocs directing users to the replacement;
- `postgres_to_ecto` `0.1.2` is a fully renamed, verified, accepted, published package with no compatibility aliases;
- lightweight tags `v0.1.1` and `v0.1.2` point to their exact accepted release commits;
- the public repository/source URL uses `postgres_to_ecto`;
- both old Hex versions are retired with reason `renamed` and the correct destination;
- root, docs, disposable-demo, archive, rename-audit, and artifact-cleanliness gates pass;
- migration guidance protects user-owned source and accurately describes the breaking rename;
- durable state records public verification and the next owner/action;
- all temporary checkout/publication scaffolding is removed after use;
- no agent performs user-owned irreversible actions without explicit authority.
