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
  "history": [
    { "stage": "fetched", "startedAt": "2026-10-20T09:00:00+07:00", "finishedAt": "2026-10-20T09:01:10+07:00",
      "minutes": 1.2, "userTurns": 0, "notes": "" }
  ]
}
```

Stages, in order: `fetched`, `clarified`, `specified`, `implemented`, `reviewed`, `tested-local`,
`tested-dev`, `tested-qa`, `documented`, `logged`. (`commit-draft` does not change the stage.) `tested.<env>` holds `{ "at": "...", "passed": 7, "failed": 0 }`.
Every skill that finishes its stage appends to `history` and updates `stage`.

### Timing (every skill, every run)
- **At the start** of a skill run, read the current local time with a shell command (`date -Iseconds`, or
  `Get-Date -Format o` in PowerShell) and keep it. Never guess the time.
- **At the end** (stage finished, or the user stops), read the time again and append one `history` entry:
  `startedAt`, `finishedAt`, `minutes` (wall clock, 1 decimal), `userTurns` (how many times the user had to
  answer or correct you during this run), and short `notes` (e.g. "stopped by user", "waited for deploy").
- A stage run more than once gets one entry per run. `dev-flow` sums them.
- Wall-clock time includes time spent waiting for the user. That is intended: it is what the ticket cost.

## 4. Running the scripts

Scripts are PowerShell 7 (`pwsh`) in `<plugin-root>/scripts/`. Run them from the project root so they
find `.dev-flow.json`:

```
pwsh -NoProfile -File "<plugin-root>/scripts/fetch-ticket.ps1" WEC-123 -OutDir docs/tickets/WEC-123
```

If an Atlassian MCP server (Jira tools) is connected, it may be used instead of the Jira scripts.

### Searching code fast
- Search **only inside the current repo** (the folder with `.dev-flow.json`), never a parent folder that holds
  several repos.
- Prefer `git grep -n "<pattern>" -- <path>` (tracked files only, skips build output), or `rg` if installed.
  Avoid `grep -r` / `find` over the whole tree.
- Always exclude `bin/`, `obj/`, `node_modules/`, `dist/`, `.git/`, `packages/`, logs and caches.
- Narrow first (one folder or one file pattern, e.g. `-- '*.cs'`), widen only if nothing is found.
- In Cowork, every command crosses a bridge to the user's machine and is slow: batch several searches into
  one command instead of many small ones.

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
