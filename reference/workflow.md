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

Local-only work (tickets, API test config and logs, cache) lives in a **workspace folder**, set by `"workspace"` in
`.dev-flow.json`. Its location is **chosen by the user in `setup-project`**; there is no hard-coded default. A typical
choice is a folder **next to the repos**, shared by every repo in the same parent, so one ticket that touches several
repos (e.g. backend + database) has one folder.

**Example only** — folder name and location are whatever the user chose in `setup-project`; never assume them:
```
<parent folder>/
├── <workspace folder>/          ← e.g. ".dev-flow", chosen by the user (never a git repo)
│   ├── tickets/<KEY>/           ticket.md, questions.md, spec.md, state.json, timing.json …
│   ├── API_test/<repo>/         config_swagger.json (secrets), API-Test-Log*.md, API-Comments.md
│   └── cache/<repo>/            raw Jira / PR / API responses
├── repo-a/  .dev-flow.json  →  "workspace": "../<workspace folder>"
└── repo-b/  .dev-flow.json  →  "workspace": "../<workspace folder>"
```

| What | Where | Committed? |
|---|---|---|
| Process (skills, scripts, templates) | this plugin | plugin repo |
| Project settings (no secrets) | `<repo>/.dev-flow.json` | personal by default (`.git/info/exclude`); commit only if the team adopts the plugin |
| Coding rules | `paths.rules` (relative to the **repo**) | as the project decides |
| Optional rule overrides | `paths.apiDocRules`, `paths.commitRules` (relative to the repo) | as the project decides |
| Ticket workspace | `<workspace>/<paths.tickets>/<KEY>/` (default `tickets/<KEY>/`) | **never** (outside the repo) |
| API test config, logs, FE API doc | `<workspace>/<apiTest.*>` (default `API_test/<repo>/…`) | **never** |
| Raw API/Jira responses | `<workspace>/cache/<repo>/` | **never** |
| Atlassian credentials | `~/.dev-flow/credentials.json` or env vars | **never** |
| Timing, feedback log | `<ticket>/timing.json`, `~/.dev-flow/plugin-log.jsonl` | **never** |

**Path rule:** in `.dev-flow.json`, `paths.tickets` and every `apiTest.*` path are **relative to the workspace**;
`paths.rules`, `apiDocRules`, `commitRules` are relative to the **repo**. Without `workspace`, everything is relative to
the repo (older setup: `docs/tickets`, `docs/API_test`). Scripts resolve this themselves; when you read or write these
files directly, resolve them the same way.

If `.dev-flow.json` is missing, the scripts stop with "run setup-project": nothing is written anywhere until the user
has chosen the locations.

## 3. Ticket workspace

```
<tickets dir>/<KEY>/
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
  "ticket": "PROJ-123",
  "title": "…",
  "stage": "fetched",
  "specApproved": false,
  "branch": "feature/PROJ-123-short-name",
  "tested": { "local": null, "dev": null, "qa": null },
  "codeChangedAt": "2026-10-20T10:40:00+07:00",
  "history": [
    { "stage": "fetched", "startedAt": "2026-10-20T09:00:00+07:00", "finishedAt": "2026-10-20T09:01:10+07:00",
      "minutes": 1.2, "userTurns": 0, "notes": "" }
  ]
}
```

Stages, in order: `fetched`, `clarified`, `specified`, `implemented`, `reviewed`, `tested-local`,
`tested-dev`, `tested-qa`, `documented`, `logged`. (`commit-draft` does not change the stage.)
`tested.<env>` holds `{ "at": "...", "by": "agent" | "user", "passed": 7, "failed": 0, "cases": ["TC1", "..."], "notes": "" }`.
`codeChangedAt` is updated by every skill that changes the ticket's code; a `tested.<env>` older than it is **stale**
and that environment needs a retest.
Every skill that finishes its stage appends to `history` and updates `stage`.

### Timing — automatic, nothing to do
Timing is recorded by the plugin's hooks (`hooks/hooks.json` → `scripts/hooks/track.ps1`), not by you:
- every user prompt and every end of turn is timestamped from the real clock;
- when a ticket's `state.json` `stage` changes, an entry is appended to `<tickets>/<KEY>/timing.json`
  (stage, start, finish, wall minutes, active minutes, user turns);
- when the stage becomes `logged`, the ticket summary is written to the plugin log.
So: **just keep `state.json.stage` up to date** at the end of each stage. Never write times yourself, never edit
`timing.json`. To show the table run `pwsh -NoProfile -File "<plugin-root>/scripts/stage-timer.ps1" show -Ticket <KEY>`.
Switches: `pwsh -NoProfile -File "<plugin-root>/scripts/tracking.ps1" status|on|off [-Feature timing|feedback] [-Project]`.

### Plugin feedback log (for evaluating the plugin)
Only when `tracking.feedbackLog` is on (`tracking.ps1 status`; the script itself ignores calls when it is off).
Append one line with `pwsh -NoProfile -File "<plugin-root>/scripts/plugin-log.ps1" add -Ticket <KEY> -Skill <skill> -Type <type> -Note "<one line>"`
**at the moment it happens**:
- `correction`: the user had to correct, stop or redirect you ("dừng lại", "không phải vậy", "hỏi tôi luôn"…).
- `rule-break`: you notice you broke a plugin rule (forgot the timer, went over the clarify budget, guessed a time,
  ran something that needed consent…). Be honest; this is what improves the plugin.
- `stuck`: you could not continue without the user doing something (missing DB, expired token, script error).
- `good`: something worth keeping (a question that changed the design, a real bug found in review).
Notes are one short line about the process. Never put code, customer data or secrets in them.
The ticket summary is written automatically when the stage becomes `logged`. If the ticket ends without `work-log`
(the user says it is done), run `plugin-log.ps1 ticket-summary -Ticket <KEY> -Skipped "<stages skipped and why>"` once.
The log lives in `~/.dev-flow/plugin-log.jsonl`, outside every repo. `plugin-log.ps1 summary` prints the overview.

## 4. Running the scripts

Scripts are PowerShell 7 (`pwsh`) in `<plugin-root>/scripts/`. Run them from the project root so they
find `.dev-flow.json`:

```
pwsh -NoProfile -File "<plugin-root>/scripts/fetch-ticket.ps1" PROJ-123
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
- Before committing, make sure nothing from the workspace, the cache or `apiTest.configFile` is inside the repo
  (or, for older in-repo setups, that they are git-ignored).

## 6. Git

Never run `git commit` or `git push`. Skills may `git add` and draft messages (`commit-draft`); the user
commits and pushes. Creating or switching branches needs the user's OK.

## 7. Local testing and databases

Each project tests differently; `.dev-flow.json` → `testing` says how.
- `testing.localEnvironment = "user"` (default): the user starts databases and apps. Before a test step, show the
  `prerequisites` checklist, **stop and wait** until the user says it is ready. Never start, restore, create or
  drop databases yourself.
- `testing.localEnvironment = "agent"`: you may run `startCommands`.
- **Never create, restore, attach or drop any database, temporary or not.** There is no setting that allows it.
  If a test needs a database that is not there, mark the case NOT RUN and tell the user what is needed.
- Never run scripts against any database without the user's OK.
- Report each test case honestly as PASS / FAIL / PARTIAL (what was not covered) / NOT RUN (why).

### User-verified results
When the user says they tested something themselves ("tôi đã test xong", "verified", "all good"):
1. Ask, in one message, only for what is missing: environment, which test cases (or "all"), result per case if not
   all PASS, and whether it was on the **current** code (after the last change, `codeChangedAt`). Accept short answers.
2. Do not re-run those cases and do not mark more than the user confirmed.
3. Record it:
   - In the environment's API test log (or `review.md` / `implementation-notes.md` when there is no API log), an entry
     headed `Verified by <user name> (manual)` with date/time, environment, cases, results and the user's notes.
   - In `state.json`: `tested.<env> = { at, by: "user", passed, failed, cases, notes }`, and advance the stage
     (and close the related review finding) exactly as if you had run the tests.
4. If the user tested an older version of the code, record it but keep the environment marked stale and say so.

## 8. Shared environments

`apiTest.sharedEnvironmentsNeedConfirmation` (default `dev`, `qa`) lists environments other people use.
On those, GET calls are free, but any POST/PUT/PATCH/DELETE needs the user's OK first (one confirmation
for the whole planned batch is enough). Record ids of any data created so it can be cleaned up.

## 9. Language

`language.conversation` for talking to the user, `language.workNotes` for questions/spec/test logs,
`language.apiDoc` for the FE API doc. Code, identifiers and commit messages stay in English.
