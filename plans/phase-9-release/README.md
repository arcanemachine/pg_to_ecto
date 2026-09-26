# Phase 9: `0.1.0` Release

## Lifecycle status

- Planning status: Complete and execution-ready
- Execution status: Ready for owner pickup
- Current owner: Sergeant
- Selected execution route: Standard coordinated route
- Public-release authority: User-owned remote actions only; no agent authority

## Purpose

Publish the already accepted Wave 1 product as PgToEcto `0.1.0` through a small, manual, auditable release process. This phase converts the accepted Phase 8 release candidate into final package documentation, proves the exact package archive, creates the local release commit and lightweight tag after the required gates, and hands the irreversible remote operations to the user.

The phase does not reopen Wave 1 implementation or activate Wave 2. Its value is traceability: the package on Hex, the source commit, the `v0.1.0` tag, the installation instructions, and the changelog must all describe the same accepted product.

## Present facts

- Phases 6–8 are implementation-complete, verified, accepted, and integrated.
- `mix.exs` already declares version `0.1.0` and complete Hex package metadata.
- `README.md` already uses the `~> 0.1.0` installation requirement but still describes the project as pre-release.
- `CHANGELOG.md` contains an unpublished `0.1.0` candidate entry.
- A local `mix hex.build` succeeds and includes the intended library, formatter export, project metadata, README, changelog, and license. The inspection artifact was removed afterward.
- The public Hex registry did not contain a package named `pg_to_ecto` when planning evidence was gathered. This must be rechecked immediately before publication because registry availability can change.
- No Git tag exists for this project.
- The local `main` branch was 11 commits ahead of `origin/main` when planning began. The accepted source and release commit must be available at the package's public source URL before publication.
- No release automation exists.

## Accepted release decisions

1. The public release consists of the Hex package and a lightweight `v0.1.0` Git tag.
2. No GitHub Release is created.
3. The initial release uses a manual, explicitly gated process. Release automation is outside scope.
4. Release documentation follows Keep a Changelog and Semantic Versioning conventions.
5. The release commit subject is `chore: release v0.1.0`.
6. The lightweight tag points exactly to the release commit.
7. The user, not an agent, pushes commits and tags and publishes to Hex.
8. Approval of this plan and selection of the standard coordinated route authorize the reset-safe planning handoff commit, routine in-plan Worker dispatch, accepted integration commits, and the local lightweight tag after the stated acceptance gates.
9. Public pushes, Hex publication, credential use, and any other irreversible remote action remain user-owned and are not authorized for agents.

The lightweight tag decision supersedes the earlier provisional suggestion to use an annotated tag because the adopted release process explicitly uses lightweight tags.

## Scope

### Included

- Add the durable release procedure to `AGENTS.md`.
- Finalize the `0.1.0` changelog entry and README release status without changing documented capability claims.
- Confirm that `mix.exs`, README installation guidance, and changelog metadata all identify version `0.1.0`.
- Run the full root and disposable-demo verification gates against the release candidate.
- Build and inspect the exact Hex archive without publishing it.
- Present the final documentation, verification, archive metadata, file list, and package checksum for user acceptance.
- Perform bounded architecture acceptance focused on release boundaries and package honesty.
- After all required acceptance and authority gates, create the release commit and local lightweight tag.
- Hand the remote push and Hex publication steps to the user.
- Verify the public package and tag after the user reports successful publication, then align durable lifecycle state.

### Excluded

- Product behavior, library API, generator output, CLI, schema, migration, introspection, or demo behavior changes.
- Wave 2 or other capability work.
- Dependency or supported-runtime changes.
- Release automation, CI changes, or a GitHub Release.
- Publishing prerelease variants or changing the target away from `0.1.0`.
- Agent access to, inspection of, or transmission of Hex credentials.
- Agent-performed pushes or Hex publication unless the user later grants separate explicit authority, which is not the planned route.
- Company systems, company data, or non-disposable databases.

If release preparation exposes a required product, dependency, runtime, security, packaging, or capability change, stop. That finding is new scope and requires an Architect decision before work continues.

## Authoritative release surfaces

- `AGENTS.md` owns the repeatable release procedure and authority boundaries.
- `mix.exs` owns the package version, dependencies, package file list, licensing, source link, description, and documentation build configuration.
- `README.md` owns installation guidance, current public status, public usage, ownership behavior, and capability claims.
- `CHANGELOG.md` owns versioned user-facing release notes. Published entries are immutable.
- `PLAN.md` owns the current lifecycle state and next owner/action.
- This phase README owns the `0.1.0` release scope, sequence, gates, and completion criteria.

Do not duplicate detailed product behavior into coordination files. Release-facing documents may summarize established behavior but must not introduce claims beyond the accepted Wave 1 surface.

## Execution sequence

### 1. Planning integration

The Architect records the durable release procedure in `AGENTS.md`, creates this phase plan and its task packet, and aligns `PLAN.md`. These planning changes establish the approved release boundaries but do not themselves perform release execution, tagging, pushing, or publication.

The plan and standard coordinated route are approved. Architect commits the reset-safe planning handoff, Sergeant becomes current owner with execution marked `Ready for owner pickup`, and Sergeant may begin routine in-plan dispatch after recovering the committed state. No additional dispatch or integration-commit confirmation is required before the plan's stated acceptance gates.

### 2. Release-document preparation

Task packet: `plans/phase-9-release/task-01-release-documentation.md`

A Worker updates only the authorized release-document surfaces. The intended result is:

- `README.md` no longer calls the project pre-release and accurately identifies the released Wave 1 surface as `0.1.0`.
- The installation dependency remains `~> 0.1.0`.
- `CHANGELOG.md` gains the standard Keep a Changelog and Semantic Versioning introduction.
- The candidate heading becomes `## [0.1.0] - YYYY-MM-DD`, using the actual release date established during execution.
- The entry describes the accepted Wave 1 public capability, diagnostics, managed-source behavior, and safety posture in user-facing terms.
- Candidate-only text stating that publication remains gated is removed from the package-facing changelog once the entry is finalized.
- No public behavior claim expands beyond the accepted README capability matrix and Phase 8 evidence.
- `mix.exs` remains unchanged unless verification finds a direct release-metadata mismatch. Any dependency, runtime, package-file, source-link, or description change is a stop condition for Architect review rather than Worker discretion.

### 3. Sergeant review and deterministic verification

Sergeant reviews the task diff for scope, accuracy, and consistency before running release verification.

Required root checks:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix docs
git diff --check
```

`mix docs` must complete without ignored warnings. If the installed ExDoc version supports an explicit warnings-as-errors option, Sergeant may use it; otherwise every emitted warning is treated as a failure and resolved.

Required demo checks, using only the documented synthetic disposable PostgreSQL source and target:

```text
cd demo
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

The demo verification must use the documented `pg_to_ecto*` disposable naming family, require `POSTGRES_PASSWORD`, avoid printing credentials, preserve the accepted canonical outputs byte-for-byte and mode-for-mode, and leave no runtime artifacts.

After verification, Sergeant confirms:

- `git diff --check` is clean;
- no package archive, generated docs, database dump, temporary file, or other runtime artifact remains tracked or untracked;
- the working tree contains only the intended release and coordination changes;
- the accepted root and demo behavior remains unchanged.

A missing disposable database service or credential is an infrastructure blocker. Report it and stop rather than skipping the demo gate or substituting weaker evidence.

### 4. Exact package inspection

With the verified candidate tree, Sergeant runs `mix hex.build` without publishing. Record:

- package name and version;
- dependencies and runtime flags as emitted by Hex;
- description, license, links, Elixir requirement, and build tool;
- complete archive file list;
- package checksum;
- confirmation that demo, tests, build output, local configuration, credentials, and coordination-only plans are absent from the archive.

Inspect package-facing README and changelog content from the candidate tree. Remove the generated `pg_to_ecto-0.1.0.tar` after recording the evidence, and confirm the tree is clean apart from intended tracked changes.

Recheck that `pg_to_ecto` remains available on Hex immediately before presenting final release evidence. A newly registered package with that name is a hard stop requiring a user naming decision.

### 5. User acceptance gate

Sergeant presents a concise release-candidate acceptance report containing:

- the exact intended release commit diff;
- verification commands and outcomes;
- archive metadata, full file list, and checksum;
- the final README status wording and changelog entry;
- confirmation that no product code, dependency, runtime, or capability changed;
- confirmation that the Hex name remained available at the time checked;
- the remaining local and remote actions.

The user must explicitly accept the release candidate or waive this acceptance gate. Automated verification does not replace this approval. Rejection returns the documentation task for same-task correction when possible.

### 6. Architecture acceptance gate

After user acceptance, Architect performs a bounded sanity pass covering:

- conformity to this phase's scope and non-goals;
- unchanged PostgreSQL source-authority and read-only-introspection posture;
- unchanged generated-source ownership and user-owned-byte preservation behavior;
- honest capability, diagnostic, and unsupported-mapping claims;
- package contents and dependency posture;
- complete root and real disposable-PostgreSQL evidence;
- user acceptance disposition;
- release authority boundaries and exact next owner/action.

Architect reports findings and waits for the user before recording acceptance or advancing to closeout. Rejection names the blocking finding and correction owner.

### 7. Local release closeout

After user and architecture acceptance, the approved standard coordinated route grants Sergeant integration authority to:

1. updates `PLAN.md` and this phase README to the precise pre-publication state;
2. confirms version `0.1.0`, README `~> 0.1.0`, and changelog `[0.1.0]` metadata agree;
3. runs the final required checks affected by closeout edits;
4. stages only the accepted release and coordination files;
5. creates the release commit with subject `chore: release v0.1.0`;
6. confirms the release commit contains no unrelated or generated files;
7. creates the lightweight tag with `git tag v0.1.0 <release-commit>` and verifies that the tag resolves exactly to the release commit.

The approved release plan and route authorize this local tag after the acceptance gates. Do not ask for a redundant local-tag confirmation.

Do not push the branch or tag and do not publish to Hex.

### 8. User-owned public release

The user performs the remote operations using their own Git and Hex authentication:

1. push the release commit so the package's source URL resolves to the released source;
2. push lightweight tag `v0.1.0`;
3. publish `pg_to_ecto` version `0.1.0` to Hex.

The agent may provide exact commands at the gate, but must not request credential values or ask the user to paste sensitive output. Failure after any public step is a release blocker; preserve the exact state and recover forward rather than rewriting published history or attempting an unapproved replacement package.

### 9. Post-publication verification and lifecycle closeout

After the user reports completion, the active owner verifies without credentials that:

- Hex exposes package `pg_to_ecto` version `0.1.0` with the expected metadata and checksum where available;
- public documentation renders successfully;
- remote tag `v0.1.0` resolves to the release commit;
- the public source link resolves to that commit;
- the installation requirement shown publicly remains `~> 0.1.0`.

Then align `PLAN.md` and this phase README to `Released and closed`, record the next substantive owner/action, verify coordination-only changes, and commit them only when the approved route grants authority. The user remains responsible for pushing any post-publication closeout commit.

## Stop conditions

Stop and return to the named owner if:

- the Hex package name is no longer available;
- any version, dependency, runtime, package-file, source-link, license, or capability claim needs to change;
- release documentation would claim behavior outside accepted Wave 1 scope;
- root or demo verification fails or emits warnings;
- the disposable PostgreSQL prerequisites are unavailable;
- verification changes accepted canonical outputs or leaves artifacts;
- the archive contains an unintended or sensitive file;
- the working tree contains unrelated changes;
- the candidate commit does not contain all source currently absent from `origin/main`;
- required user acceptance or architecture acceptance is missing;
- an agent would need to perform a user-owned remote push or Hex publication;
- a credential would need to be exposed to an agent;
- a public push or publication partially succeeds and the next recovery action is not explicit.

## Completion criteria

Phase 9 is complete only when:

- release documentation and package metadata consistently identify `0.1.0`;
- all root, docs, demo, diff, artifact-cleanliness, and archive-inspection gates pass;
- the user accepts the exact candidate;
- architecture acceptance is recorded;
- `chore: release v0.1.0` is the accepted release commit;
- lightweight tag `v0.1.0` resolves to that commit;
- the user has pushed the release source and tag and published version `0.1.0` to Hex;
- public package, documentation, source, and tag verification passes;
- durable lifecycle state records the release as closed and names the next owner/action.
