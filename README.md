# tai-dev-flow

A Claude Code plugin that standardises a backend developer's ticket workflow, from Jira ticket to FE handoff:

```
setup-project (once per project)

ticket-fetch → ticket-clarify → ticket-spec ⏸ → implement → code-review ⏸ → api-test local
            → commit-draft ⏸ (you commit/push/deploy) → api-test dev → api-test qa → api-doc ⏸ → work-log ⏸
```

⏸ = stops and waits for your approval. `dev-flow <KEY>` runs or resumes the whole chain.

## Skills

| Skill | Command | What it does |
|---|---|---|
| setup-project | `/tai-dev-flow:setup-project` | One-time project setup: `.dev-flow.json`, personal configs, `.gitignore`, rules check |
| dev-flow | `/tai-dev-flow:dev-flow PROJ-123` | Shows where a ticket stands and continues from the next stage |
| ticket-fetch | `/tai-dev-flow:ticket-fetch PROJ-123` | Jira ticket → `docs/tickets/PROJ-123/ticket.md` |
| ticket-clarify | `/tai-dev-flow:ticket-clarify PROJ-123` | Asks you questions one at a time → `questions.md` (D# decisions, OQ# open questions) |
| ticket-spec | `/tai-dev-flow:ticket-spec PROJ-123` | `spec.md`: scope, AC, API contract, DB, plan, test cases (TC#) — needs your approval |
| implement | `/tai-dev-flow:implement PROJ-123` | Codes the approved spec using the **project's** rules, tests first where possible |
| code-review | `/tai-dev-flow:code-review` or `... my-api 123` | Reviews the branch diff or a Bitbucket PR against the rules and the spec |
| api-test | `/tai-dev-flow:api-test dev PROJ-123` | Runs the spec's test cases against real APIs, appends to `API-Test-Log_<env>.md` |
| commit-draft | `/tai-dev-flow:commit-draft PROJ-123` | Stages the files and drafts a Conventional Commits message — never commits or pushes |
| api-doc | `/tai-dev-flow:api-doc PROJ-123` | FE API comment per the API documentation rules (scope, full URLs, annotated request + enum tables, real response, exact errors, Notes for FE) — draft only |
| work-log | `/tai-dev-flow:work-log PROJ-123 2h` | Logs work on **one Jira ticket** after you confirm |
| timekeeper-log | `/tai-dev-flow:timekeeper-log 2026-09` | Logs a **whole month to Timekeeper**: tickets from Jira (MCP/Rovo or REST), leave + holidays from SRM, 8h/day split evenly, posted through your logged-in browser |

Skills without `disable-model-invocation` can also be picked up automatically, e.g. "fetch PROJ-123", "test dev", "review my changes".

## Install

Requirements: Claude Code, PowerShell 7 (`pwsh`) — `winget install Microsoft.PowerShell` / `brew install powershell`. For browser logins: the Claude app's built-in browser, or Playwright MCP in VS Code / Antigravity.

```bash
claude plugin marketplace add homautai/tai-dev-flow
claude plugin install tai-dev-flow@tai-dev-flow
```

The repository is private: everyone who installs needs read access on GitHub and git authentication on their machine (`gh auth login`).

Local development (no install):
```bash
claude --plugin-dir "D:\tai-dev-flow"
```

The skills are plain `SKILL.md` files, so they can also be used by other agents that support Agent Skills (e.g. GitHub Copilot in VS Code).

## Automatic tracking

The plugin ships Claude Code hooks (`hooks/hooks.json`) that time each ticket stage from the real clock and count
your turns, writing `docs/tickets/KEY/timing.json`. Nothing to call by hand. Turn it off when you no longer need it:

```
pwsh -File <plugin>/scripts/tracking.ps1 off            # all projects, for you
pwsh -File <plugin>/scripts/tracking.ps1 off -Project   # this project only
```
Or just ask Claude: "tắt tracking". Hooks need PowerShell 7 (`pwsh`).

## Built-in rules

| Rule | File | Project override (`.dev-flow.json`) |
|---|---|---|
| API documentation | `skills/api-doc/references/api-documentation.md` | `paths.apiDocRules` |
| Commit messages (Conventional Commits, English, never commit/push) | `skills/commit-draft/references/commit-instructions.md` | `paths.commitRules` |

Coding rules are **not** in the plugin — they belong to each project (`paths.rules`).

## Configuration — what goes where

| File | Contains | Commit? |
|---|---|---|
| `<project>/.dev-flow.json` | Jira URL, Bitbucket workspace, folders, log file names, languages | ✅ yes |
| `<project>/.claude/rules/rule.md` (+ files it lists) | the project's coding rules | ✅ yes |
| `~/.dev-flow/credentials.json` | Atlassian email + Jira/Bitbucket API tokens | ❌ never |
| `<project>/docs/API_test/config_swagger.json` | base URLs per env, bearer tokens, OAuth client, test users | ❌ never |
| `~/.dev-flow/timekeeper.json` | Timekeeper/SRM URLs, your user id, codes, ticket sources (no tokens) | ❌ personal |

Templates for all of them are in `templates/`. Run `/tai-dev-flow:setup-project` in each project and it will create them with you.

Credentials can also come from environment variables: `DEVFLOW_ATLASSIAN_EMAIL`, `DEVFLOW_JIRA_API_TOKEN`, `DEVFLOW_BITBUCKET_API_TOKEN`, and per-environment bearer tokens `DEVFLOW_TOKEN_<ENV>` (e.g. `DEVFLOW_TOKEN_DEV`).

`config_swagger.json` accepts both the new format (`environments.<env>.baseUrl`) and the older flat format (`baseUrl`, `baseUrl_dev`, `bearerToken`, …).

## Bearer tokens for API tests

`api-test` resolves a token in this order:

1. existing token in `config_swagger.json` (expired JWTs are detected before calling)
2. **browser login (default)**: the agent opens the project's UI (`login.url`) in its browser (Claude app: built-in browser; VS Code / Antigravity: Playwright MCP), **you log in yourself**, the token is read from the page and saved with `scripts/save-token.ps1`
3. `scripts/get-token.ps1`: only for identity servers that allow password / client_credentials grants (`auth.tokenUrl` set)
4. no browser tool: you capture it in DevTools and paste it into the config file

Where each project keeps its token (localStorage / sessionStorage / Authorization header) is detected at the first login and stored in `config_swagger.json` (`login.tokenFrom`, `login.tokenKey`).

Tokens are never printed, logged or sent to the chat.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/fetch-ticket.ps1 <KEY> [-OutDir dir]` | Jira issue → Markdown |
| `scripts/fetch-pr.ps1 <repo> <prId> [workspace]` | Bitbucket PR metadata, diff, comments |
| `scripts/logwork-jira.ps1 <KEY> <time> [comment] [started]` | Jira worklog |
| `scripts/call-api.ps1 -Target dev -Method GET -Path /x -Expect 200` | API call with token from config, token masked |
| `scripts/stage-timer.ps1 show -Ticket KEY` | Timing table per stage (recorded automatically by hooks) |
| `scripts/tracking.ps1 status/on/off` | Turn automatic timing / feedback log on or off (personal or `-Project`) |
| `scripts/plugin-log.ps1 add/ticket-summary/summary` | Plugin evaluation log in `~/.dev-flow/plugin-log.jsonl`: corrections, rule breaks, blockers, per-ticket summaries |
| `scripts/show-config.ps1 <file>` | Print a personal config with every secret masked |
| `scripts/save-token.ps1 -Target dev -Token <v>` | Save a token captured from the browser login into the config (prints expiry only) |
| `scripts/get-token.ps1 -Target dev` | Optional: OAuth2 password/client_credentials token → config (not printed) |
| `scripts/fetch-month-tickets.ps1 -Period 2026-09 -OutFile f.json` | Tickets per source in timekeeper.json via Jira REST (JQL) |
| `scripts/plan-timekeeper.ps1 -InputFile in.json -OutDir dir` | 8h/day plan: holidays, leave, meetings, even split across active tickets; CSV + post chunks |

## Repository layout

```
.claude-plugin/   plugin.json, marketplace.json
skills/<name>/    SKILL.md for each step
scripts/          PowerShell scripts (+ lib/)
templates/        project/personal config templates and document templates
reference/        workflow.md — shared conventions every skill follows
```

## Versioning

Bump `version` in `.claude-plugin/plugin.json` and `marketplace.json` for every release so installs pick up the update.
