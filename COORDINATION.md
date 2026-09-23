# Coordination state

## Current handoff

- **Owner:** Sergeant
- **Status:** Phase 6 managed regeneration/file application in progress; `pg-to-ecto-worker` is the implementation owner.
- **Current evidence:** Phase 5 checkpoint `d75b64c` (`feat: add schema renderer`) and coordination checkpoint `6336262` are clean baselines.
- **Approved scope:** Managed-key generation and validation, key comments and opt-out, exact source patching, unowned-file refusal, key-mismatch refusal, force behavior, render-first validation, per-file safe replacement, no-op idempotence, and formatter integration without whole-file user-source rewriting. Add the required regeneration tests while preserving user virtual fields, direct `many_to_many`, functions, changesets, and custom migration code around `generated_change`.
- **Scope boundary:** The Mix task, documentation refresh, Wave 2, and later work remain gated.
- **Next action:** Dispatch the approved Phase 6 brief; Sergeant reviews and verifies the result before the Architect sanity-check and checkpoint commit.
