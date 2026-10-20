# tai-dev-flow — shared conventions

Every skill in this plugin follows these conventions. `<plugin-root>` is the folder that contains
`.claude-plugin/`, two levels above any `skills/<name>/SKILL.md`.

## 1. The pipeline

```
setup-project (once per project)
ticket-fetch → ticket-clarify → ticket-spec ⏸ → implement → code-review ⏸ → api-test local
  → commit-draft ⏸ (user commits/pushes/deploys) → api-test dev → api-test qa → api-doc ⏸ → work-log ⏸
```

⏸ = gate: stop and wait for the user's explicit approval before moving on.
`dev-flow <KEY>` reads the state file and continues from the next stage.

## 2. Where things live

| What | Where | Committed? |
|---|---|---|
| Process (skills, scripts, templates) | this plugin | plugin repo |
| Project settings (no secrets) | `<project>/.dev-flow.json` | yes |
| Coding rules | `paths.rules` (default `.claude/rules/rule.md` + every file it lists) | yes |
| Optional project overrides | `paths.apiDocRules`, `paths.commitRules` (win over the plugin's defaults) | yes |
| Ticket workspace | `<paths.tickets>/<KEY>/` (default `docs/tickets/<KEY>/`) | project decides |
| API test logs, API doc for FE | `apiTest.logFiles.*`, `apiTest.apiDocFile` | project decides |
| Raw API/Jira responses | `<project>/.dev-flow/cache/` | **never** (git-ignored) |
| Atlassian credentials | `~/.dev-flow/credentials.json` or env vars | **never** |
| API test config + tokens | `apiTest.configFile` (default `docs/API_test/config_swagger.json`) | **never** (git-ignored) |
| Timekeeper settings, plans, history | `~/.dev-flow/timekeeper.json`, `~/.dev-flow/timekeeper/` | personal, outside projects |

If `.dev-flow.json` is missing, use the defaults above and suggest running `setup-project`.

## 3. Ticket workspace

```
<tickets>/<KEY>/
├── state.json               progress, read by dev-flow
├── ticket.md                fetched ticket (ticket-fetch)
├── questions.md             decisions D# and open questions OQ# (ticket-clarify)
├── spec.md                  approved spec incl. test cases TC# (ticket-spec)
├── implementation-notes.md  files changed, deviations (implement)
└── review.md                review findings (code-review)
```

### state.json

```json
{
  "ticket": "WEC-123",
  "title": "…",
  "stage": "fetched",
  "specApproved": false,
  "branch": "feature/WEC-123-short-name",
  "tested": { "local": null, "dev": null, "qa": null },
  "history": [ { "stage": "fetched", "at": "2026-10-20T09:00:00+07:00" } ]
}
```

Stages, in order: `fetched`, `clarified`, `specified`, `implemented`, `reviewed`, `tested-local`,
`tested-dev`, `tested-qa`, `documented`, `logged`. (`commit-draft` does not change the stage.) `tested.<env>` holds `{ "at": "...", "passed": 7, "failed": 0 }`.
Every skill that finishes its stage appends to `history` and updates `stage`.

## 4. Running the scripts

Scripts are PowerShell 7 (`pwsh`) in `<plugin-root>/scripts/`. Run them from the project root so they
find `.dev-flow.json`:

```
pwsh -NoProfile -File "<plugin-root>/scripts/fetch-ticket.ps1" WEC-123 -OutDir docs/tickets/WEC-123
```

If an Atlassian MCP server (Jira tools) is connected, it may be used instead of the Jira scripts.

## 5. Secrets — hard rules

- Never print, echo, log, or paste a token, password, client secret or `Authorization` header.
- To look at a personal config, **always** use `pwsh -NoProfile -File "<plugin-root>/scripts/show-config.ps1" <file>`.
  It masks secrets at any depth. Never `cat` / `Get-Content` / `Read` such a file, and never write ad-hoc masking code.
- Never ask the user to paste a secret into the chat. Tell them which file/field to fill instead.
- Never write secrets into ticket files, test logs, API docs, commits or PR descriptions.
- Before committing, make sure `.dev-flow/cache/` and `apiTest.configFile` are git-ignored.

## 6. Git

Never run `git commit` or `git push`. Skills may `git add` and draft messages (`commit-draft`); the user
commits and pushes. Creating or switching branches needs the user's OK.

## 7. Shared environments

`apiTest.sharedEnvironmentsNeedConfirmation` (default `dev`, `qa`) lists environments other people use.
On those, GET calls are free, but any POST/PUT/PATCH/DELETE needs the user's OK first (one confirmation
for the whole planned batch is enough). Record ids of any data created so it can be cleaned up.

## 8. Language

`language.conversation` for talking to the user, `language.workNotes` for questions/spec/test logs,
`language.apiDoc` for the FE API doc. Code, identifiers and commit messages stay in English.
