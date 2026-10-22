---
name: dev-flow
description: Run or resume the full ticket workflow (fetch → clarify → spec → implement → review → API test local/dev/qa → FE API doc → work log) for a Jira key, continuing from the stage recorded in the ticket's state.json and stopping at each approval gate. Run explicitly with /tai-dev-flow:dev-flow KEY.
argument-hint: "<JIRA-KEY>"
disable-model-invocation: true
---

# Dev flow (orchestrator)

Read `<plugin-root>/reference/core.md` first.

1. **Setup:** if `.dev-flow.json` is missing, stop and offer `/tai-dev-flow:setup-project`. Do not continue with guessed
   folders.
2. **State:** read `<tickets dir>/<KEY>/state.json`. Missing → the next stage is `ticket-fetch`.
3. **Status** (one screen):
   ```
   PROJ-123 — <title>
   ✅ fetched  ✅ clarified  ✅ spec (approved)  ▶ implement  ☐ review  ☐ test local  ☐ commit  ☐ test dev  ☐ test qa  ☐ api doc  ☐ log work
   Open questions: OQ2 (BA)    Last activity: 2026-10-20 14:05
   ```
   Test stages: `✅` agent-run, `✅👤` user-verified, `⚠️ stale` when `tested.<env>.at` is older than `codeChangedAt`.
   Commit is not stored in state: it is done when `git log --oneline --grep <KEY>` shows it and the tree is clean.
4. **Continue** with the next stage: read `<plugin-root>/skills/<stage>/SKILL.md` and follow it in full (read the file
   directly; `setup-project` and `work-log` cannot be auto-invoked). Order:
   `ticket-fetch → ticket-clarify → ticket-spec → implement (incl. code-review) → api-test local → commit-draft
   (user commits, pushes, deploys) → api-test dev → api-test qa → api-doc → work-log`.
   Skip environments the project or ticket does not use (`apiTest.environments`, TC env columns).
5. **Gates:** stop at spec approval, review findings, writes on shared environments, API doc review, work-log
   confirmation, and anything needing a deploy by the user. Say exactly what you are waiting for.
6. **Retests:** when the ticket's code changes after a `tested-*` stage, mark those environments stale and say so.
   When the user says they tested something themselves, follow `<plugin-root>/reference/testing.md` (user-verified results).
7. **Jumps:** the user may jump to a stage ("test dev now"); allow it and point out skipped prerequisites.
8. **Small change mode:** for a small fix the user may skip clarify/spec: write a 5-line `spec.md` (problem, fix,
   test cases), mark it `APPROVED (small change)` with their OK, continue from `implement`.
9. **Time / tracking questions** ("bao lâu", "tắt tracking", "plugin log"): follow `<plugin-root>/reference/tracking.md`.
