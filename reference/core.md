# tai-dev-flow — core rules (read by every skill)

`<plugin-root>` = the folder holding `.claude-plugin/` (two levels above any `skills/<name>/SKILL.md`).
Scripts: `pwsh -NoProfile -File "<plugin-root>/scripts/<name>.ps1" …` (PowerShell 7), run from the repo root.

## Pipeline and gates
`ticket-fetch → ticket-clarify → ticket-spec ⏸ → implement → code-review ⏸ → api-test local → commit-draft ⏸
→ api-test dev → api-test qa → api-doc ⏸ → work-log ⏸`. ⏸ = stop until the user explicitly approves.

## Paths
- Project settings: `<repo>/.dev-flow.json`. If it is missing, stop and suggest `/tai-dev-flow:setup-project`;
  never pick folders yourself.
- `workspace` (chosen by the user) holds local-only work: `tickets/<KEY>/`, `API_test/<repo>/`, `cache/<repo>/`.
  `paths.tickets` and `apiTest.*` are relative to the workspace; `paths.rules`, `apiDocRules`, `commitRules` to the repo.
  No `workspace` = everything relative to the repo (older setup). Scripts resolve paths themselves.
- Ticket folder: `ticket.md`, `questions.md`, `spec.md`, `implementation-notes.md`, `review.md`, `state.json`.

## state.json
- `stage` in order: `fetched, clarified, specified, implemented, reviewed, tested-local, tested-dev, tested-qa,
  documented, logged`. **Update `stage` when your stage ends** — timing is recorded automatically from it by hooks.
  Never write or estimate times yourself, never edit `timing.json`.
- Also: `specApproved`, `branch`, `codeChangedAt` (set it whenever you change the ticket's code),
  `tested.<env> = { at, by: "agent"|"user", passed, failed, cases, notes }` (stale if older than `codeChangedAt`).

## Safety (hard rules)
- **Secrets:** never print, log or paste tokens, passwords, client secrets or `Authorization` headers. Look at personal
  config only through `scripts/show-config.ps1` (masks secrets). Never ask for a secret in chat; name the file/field.
  Never put secrets in ticket files, logs, docs, commits or PRs.
- **Git:** never `git commit` / `git push`; `commit-draft` stages and drafts, the user commits. Branch changes need OK.
- **Databases:** never create, restore, attach or drop any database (temporary included). Never run scripts against a
  database without the user's OK. Missing environment → mark the test NOT RUN and say what is needed.
- **Shared environments** (`apiTest.sharedEnvironmentsNeedConfirmation`, default dev/qa): GET is free; POST/PUT/PATCH/
  DELETE need one OK for the planned batch; record created ids.
- Report tests honestly: PASS / FAIL / PARTIAL (what is missing) / NOT RUN (why).

## Reading code
Search only inside the current repo with `git grep -n "<pattern>" -- <path>` (or `rg`); exclude `bin/ obj/
node_modules/ dist/ packages/`; narrow first, widen only if needed; batch several searches in one command.

## Language
`language.conversation` to talk, `language.workNotes` for questions/spec/test logs, `language.apiDoc` for FE docs.
Code, identifiers and commit messages: English.

## More detail, only when a skill points you there
`<plugin-root>/reference/workspace.md` (setup, layout) · `<plugin-root>/reference/testing.md` (local testing, user-verified results) ·
`<plugin-root>/reference/tracking.md` (timing table, switches, feedback log).
