# Coordination state

This file is superseded by the reset-safe coordination model.

Agents must begin with `AGENTS.md`, read only their matching role supplement, and recover current lifecycle state from `PLAN.md`. Detailed active work lives under the phase directory named by `PLAN.md`.

Do not recover ownership, gates, task status, or dispatch authority from older versions of this file. Retain this pointer only through the current transition; remove it during an authorized integration or closeout once every active session uses `PLAN.md`.
