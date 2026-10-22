# Workspace and paths (details)

Local-only work lives in a workspace folder whose location the user chooses in `setup-project` (no default).
Typical choice: a folder next to the repos, shared by sibling repos, so a ticket spanning several repos has one folder.

Example only — names and places are the user's choice:
```
<parent folder>/
├── <workspace>/                 never a git repo
│   ├── tickets/<KEY>/           ticket.md, questions.md, spec.md, state.json, timing.json …
│   ├── API_test/<repo>/         config_swagger.json (secrets), API-Test-Log*.md, API-Comments.md
│   └── cache/<repo>/            raw Jira / PR / API responses
├── repo-a/  .dev-flow.json  →  "workspace": "../<workspace>"
└── repo-b/  .dev-flow.json  →  "workspace": "../<workspace>"
```

| What | Where | Committed? |
|---|---|---|
| Project settings (no secrets) | `<repo>/.dev-flow.json` | personal by default (`.git/info/exclude`); commit only if the team adopts the plugin |
| Coding rules / rule overrides | `paths.rules`, `apiDocRules`, `commitRules` (relative to the repo) | as the project decides |
| Ticket folders | `<workspace>/<paths.tickets>/<KEY>/` | never |
| API test config, logs, FE API doc | `<workspace>/<apiTest.*>` | never |
| Raw responses | `<workspace>/cache/<repo>/` | never |
| Atlassian credentials | `~/.dev-flow/credentials.json` or env vars | never |
| Timing, feedback log | `<ticket>/timing.json`, `~/.dev-flow/plugin-log.jsonl` | never |

Without `workspace` (older setup) all paths are relative to the repo (`docs/tickets`, `docs/API_test`) and must be
git-ignored. Before any commit, nothing from the workspace, the cache or `apiTest.configFile` may be inside the repo.
