---
name: setup-project
description: One-time setup of the tai-dev-flow workflow in the current project — creates .dev-flow.json, personal credential and API-test config files from templates, git-ignore entries, and checks the coding rules index. Run explicitly with /tai-dev-flow:setup-project; other dev-flow skills suggest it when .dev-flow.json is missing.
argument-hint: "(no arguments)"
disable-model-invocation: true
---

# Setup project

Read `<plugin-root>/reference/workflow.md` first (`<plugin-root>` = two folders above this file).

Work through the checklist below in order. Ask one question at a time and always propose a default.
Show every file before writing it and write only after the user agrees.

## 1. Project root
Use the git root of the current folder. Confirm it with the user if it is not obvious.

## 2. `.dev-flow.json` (committed, no secrets)
- If it exists: show it and ask what to change.
- Otherwise start from `<plugin-root>/templates/dev-flow.template.json` and fill it in:
  - Jira site URL and Bitbucket workspace. Infer them from `git remote -v`, existing scripts or docs when you can.
  - Ticket folder: look for an existing docs folder (`docs/`, `docs/tickets/`) and follow it.
  - API test folder and log file names: if the project already has `API-Test-Log*.md` or
    `API-Comments.md`, point the config at those files. Never rename or move them.
  - Rules entry file: find `.claude/rules/rule.md`, `CLAUDE.md`, `AGENTS.md` or similar.
  - Build and unit-test commands: detect them from the solution or `package.json`, then confirm.
  - **Local testing (`testing`):** who starts the database and app (the user, or the agent with which commands),
    what must be running before tests (`prerequisites`), and the unit-test command. The agent never
    creates databases, so do not ask about that.
  - Optional overrides: does the project have its own API-doc or commit rules? If so, set
    `paths.apiDocRules` / `paths.commitRules`. Otherwise leave them empty, and the plugin defaults apply.
  - Are ticket docs (`paths.tickets`) and API test logs committed in this project, or kept local?
    If kept local, add them to `.gitignore` in step 5.

## 3. Personal Atlassian credentials (never committed)
Check `~/.dev-flow/credentials.json` and the env vars `DEVFLOW_ATLASSIAN_EMAIL` / `DEVFLOW_JIRA_API_TOKEN` /
`DEVFLOW_BITBUCKET_API_TOKEN`.
- Missing: copy `<plugin-root>/templates/credentials.template.json` to `~/.dev-flow/credentials.json`
  and tell the user to fill it in. Give them the link to create API tokens. **Never ask for tokens in chat.**
- A legacy `<project>/.jira/config.json` exists: say it still works as a fallback, and offer to move it
  to the personal file so it stops living inside the project.
- Verify by running `fetch-ticket.ps1` on a ticket key the user gives you.

## 4. Personal API test config (never committed)
At `apiTest.configFile`. Inspect it only with `scripts/show-config.ps1`.
Each project has its own file, because URLs and login differ per project.
- Missing: copy `<plugin-root>/templates/config_swagger.template.json`. Ask for each environment's
  **API base URL** and **UI login URL**. These are not secret. Leave `tokenFrom`/`tokenKey` empty:
  `api-test` detects them at the first browser login.
- Already present in the legacy flat format (`baseUrl`, `baseUrl_dev`, `baseUrl_dev_UI`, …): keep it.
  The scripts read both formats.
- Explain how tokens get there: the user logs in through the agent's browser, and the token is saved
  by `save-token.ps1` (see the api-test skill, "Token").
- Check which browser tool this agent has. In VS Code / Antigravity, suggest Playwright MCP if it is
  missing (`npx @playwright/mcp@latest`).

## 5. Ignore personal files
Where to write the ignore lines:
- **Personal / local-only setup (default):** `.git/info/exclude`. It works like `.gitignore` but is never
  committed, so the team's repo is not touched.
- **Team setup (the team agreed to use the plugin):** the repo's `.gitignore`. That is a shared file, so
  the change must be committed by the user.

Ask which one, recommending `.git/info/exclude`. Make sure these lines exist there. Show the diff and get an OK before editing:
```
.dev-flow/cache/
<apiTest.configFile>
.jira/config.json
.jira/cache/
```
If ticket docs / API test logs are local-only (step 2), add `paths.tickets` and the `apiTest` log, doc and config
paths to the same file.
If a secret file is **already tracked** (`git ls-files` shows it), warn the user clearly. They must
`git rm --cached` it **and rotate the secrets**, because they are in git history.

## 6. Coding rules
- If the rules entry file exists, list the files it references and confirm they all exist.
- If there are none, offer to draft a rules index from the codebase's existing conventions, marked as
  DRAFT for the user to review. Do not invent rules the code does not follow.

## 7. Tooling check
Run `pwsh -v`. If it is missing, tell the user that all scripts need PowerShell 7
(`winget install Microsoft.PowerShell` on Windows, `brew install powershell` on macOS).

## 8. Finish
Print a checklist with ✅/❌ for each item above, and the next step: `/tai-dev-flow:dev-flow <KEY>`.
