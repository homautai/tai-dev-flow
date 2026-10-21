---
name: code-review
description: Review code changes against the project's coding rules index and the ticket spec — either the current branch diff or a Bitbucket pull request — and report findings with severity, file:line and the rule section violated. Use after implement, or when the user asks to review code, review a PR, or check a diff against the rules.
argument-hint: "[<repo> <pr-id>]"
---

# Code review

> **Tracking:** timing is automatic; just update `state.json.stage` when this stage ends. If feedback logging is on,
> log each user correction, rule break or blocker with `plugin-log.ps1 add` (workflow.md §3).


Read `<plugin-root>/reference/workflow.md` first.

## What to review
- **No arguments:** the current branch vs its base (`git merge-base` with `develop`/`main`), plus uncommitted changes.
- **`<repo> <pr-id>`:** run `pwsh -NoProfile -File "<plugin-root>/scripts/fetch-pr.ps1" <repo> <pr-id>`,
  then read the saved `.diff` and comments from `.dev-flow/cache/`. For a GitHub repo, use
  `gh pr diff <id>` and `gh pr view <id> --comments` instead. Do not repeat issues that existing
  comments already raised and that are resolved.

## How
1. Load the rules entry file and **every** file it lists. Treat them as the checklist, section by section.
   Do not skip a file because its name sounds unrelated.
2. If a ticket workspace exists for this change, also check:
   - spec conformance: every AC and TC is covered, the API contract matches, nothing out of scope slipped in
   - `implementation-notes.md` deviations are justified
3. Look beyond the rules for real defects: null and edge handling, tenant isolation, N+1 queries,
   missing validation, transaction boundaries, breaking API changes.
4. Read the surrounding code before reporting. Only report what you have verified. Avoid style nitpicks
   that the rules do not ask for.

## Output
A table sorted by severity:

| # | Severity | File:line | Rule (file §) | Problem | Suggested fix |
|---|---|---|---|---|---|

Severity is one of: **Blocker** (bug, security, data loss), **Major** (rule violation with real impact), **Minor**, **Suggestion**.

- With a ticket context, save the table to `<tickets>/<KEY>/review.md` and set the stage to `reviewed`
  once the blockers and majors are fixed.
- For your own changes in this session, offer to fix them. For a colleague's PR, draft the review
  comments but never post them yourself.
