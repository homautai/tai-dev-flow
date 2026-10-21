---
name: dev-flow
description: Run or resume the full ticket workflow (fetch → clarify → spec → implement → review → API test local/dev/qa → FE API doc → work log) for a Jira key, continuing from the stage recorded in the ticket's state.json and stopping at each approval gate. Run explicitly with /tai-dev-flow:dev-flow KEY.
argument-hint: "<JIRA-KEY>"
disable-model-invocation: true
---

# Dev flow (orchestrator)

Read `<plugin-root>/reference/workflow.md` first.

1. If `.dev-flow.json` is missing, offer `setup-project` first. You may continue with the defaults if the user prefers.
2. Read `<tickets>/<KEY>/state.json`. If it is missing, the next stage is `ticket-fetch`.
3. Show a one-screen status:
   ```
   WEC-123 — <title>
   ✅ fetched  ✅ clarified  ✅ spec (approved)  ▶ implement  ☐ review  ☐ test local  ☐ commit  ☐ test dev  ☐ test qa  ☐ api doc  ☐ log work
   Open questions: OQ2 (BA)    Last activity: 2026-10-20 14:05
   ```
   When asked "how long" / "thời gian", or when the ticket reaches `logged`, also show a timing table from
   `history`: stage, runs, minutes, user turns, plus the total. Use it as the default suggestion for `work-log`.
4. Continue with the next stage. Read `<plugin-root>/skills/<stage>/SKILL.md` and follow it in full.
   Read the file directly. Some stages (`setup-project`, `work-log`) cannot be auto-invoked as skills.
   `ticket-fetch` → `ticket-clarify` → `ticket-spec` → `implement` (includes `code-review`) → `api-test local`
   → `commit-draft` (the user commits, pushes and deploys) → `api-test dev` → `api-test qa` → `api-doc` → `work-log`.
   Skip environments the project or ticket does not use (`apiTest.environments`, TC env columns).
5. Stop at every gate:
   - spec approval
   - review findings
   - writes on shared environments
   - API doc review
   - work log confirmation
   - anything that needs a deploy the user must do

   Tell the user exactly what you are waiting for.
6. Commit status is not stored in `state.json`. Check `git log --oneline --grep <KEY>` and `git status`:
   if the ticket's changes are committed and the tree is clean, treat `commit` as done.
7. When the ticket's code changes after `tested-*` (a fix or new requirement), mark the affected
   environments as needing a retest and say so.
8. The user can jump to a stage (e.g. "test dev now"). Allow it, but point out any skipped prerequisite.
9. **Small change mode:** for a small bug fix, the user may say to skip clarify/spec. Then write a 5-line
   `spec.md` (problem, fix, test cases), mark it `APPROVED (small change)` with their OK, and continue from `implement`.
