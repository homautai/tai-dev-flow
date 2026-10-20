---
name: api-test
description: Run a ticket's spec test cases against real APIs on local, dev or qa using the personal config_swagger.json, and append results (method/URL, body, status, key fields, conclusion) to that environment's API test log. Handles bearer tokens without exposing them. Use when the user says /api-test, test local / test dev / test qa, retest, or wants to verify endpoints after implementing or deploying.
argument-hint: "<local|dev|qa> [<JIRA-KEY>] [TC ids]"
---

# API test

Read `<plugin-root>/reference/workflow.md` first, especially §5 Secrets and §7 Shared environments.

## Inputs
- Environment: `local`, `dev`, `qa`, or any other target defined in the config (e.g. a second API).
- Ticket: from the argument or the current ticket context. Run the test cases in `spec.md` that list this
  environment, or the TC ids given. Without a spec, agree on a short list of cases with the user first.
- Config: `apiTest.configFile`. Inspect it only with `pwsh -NoProfile -File "<plugin-root>/scripts/show-config.ps1" <file>`.
- Swagger: if the config has `swaggerPath`, download it with
  `call-api.ps1 -Target <env> -Path <swaggerPath> -NoAuth -OutFile .dev-flow/cache/swagger-<env>.json`
  (drop `-NoAuth` if it needs a token). Use it to confirm routes and schemas before building request bodies.
- Extra headers (tenant, culture…): `-Header "X-Tenant: ACME"`, repeatable.

## Token
Each project logs in differently. The how-to is per environment in the config (`login.url`, `login.tokenFrom`,
`login.tokenKey`; legacy: `baseUrl_<env>_UI`). Details and snippets: `references/browser-token.md`.

1. **Existing token.** `call-api.ps1` uses the token already saved for the target. It returns exit 4
   `TOKEN_EXPIRED` if the JWT has expired. A `401` on a probe GET also means a new login is needed.
2. **Browser login (default).** Open `login.url` in the browser available to this agent:
   - Claude app: built-in browser
   - VS Code / Antigravity: Playwright MCP

   **The user types their credentials themselves** (SSO/MFA included). Never type passwords. Then:
   - First time for this environment (`tokenFrom` empty): run the detect snippet (it returns keys only),
     and write `tokenFrom`/`tokenKey` into the config.
   - Read the token with the storage snippet or the header hook, and save it with
     `pwsh -NoProfile -File "<plugin-root>/scripts/save-token.ps1" -Target <env> -Token "<value>"`.
     Never repeat it in replies, logs or docs.
3. **`get-token.ps1`.** Only if the config has an `auth.tokenUrl` (identity servers that allow
   password/client_credentials grants). Most SPA logins do not.
4. **Manual.** No browser tool: give the user the manual steps from `references/browser-token.md`. They
   paste the token into the config file, not into the chat.

## Running a case
```
pwsh -NoProfile -File "<plugin-root>/scripts/call-api.ps1" -Target <env> -Method POST -Path /x -BodyFile <tmp.json> -Expect 201
```
- Write request bodies to a temp file under `.dev-flow/cache/` instead of inline quoting.
- Exit codes: 0 pass, 1 unexpected status, 2 network error, 3 no token, 4 token expired (log in again).
- Check the body, not only the status: compare the key fields against the TC's expected result.
- Chain cases where needed. For example, create, then GET the created id, then verify the fields.
- On `dev`/`qa` (shared): GETs are free. Before any write, show the planned write calls and get **one**
  OK for the batch. Record created ids for cleanup.

## When a case fails
Diagnose before concluding:
- re-read the code path
- on local, check the API logs and the DB
- separate "my code is wrong" from "environment/data problem" (missing seed data, migration not run, wrong tenant)

Do not change the expected result to make a test pass. If the code needs a fix, describe it and fix only with
the user's OK (then retest and log the retest too).

## Logging
Append to `apiTest.logFiles.<env>`. If the file does not exist, create it from
`<plugin-root>/templates/test-log-header.md`. Each run is one dated section, following
`<plugin-root>/templates/test-log-entry.md`, written in `language.workNotes`. Keep the existing style:
- ✅/❌ with the status code
- key fields that prove the expectation
- trimmed error bodies
- a conclusion per test, and an overall conclusion per run

Use the labels of `language.workNotes`. For `vi`: Kết quả / Ghi chú / Kết luận. For `en`: Result / Notes /
Conclusion. If the log file already exists, follow the labels it already uses.

Never write tokens or Authorization headers. Anonymise personal data if it is real customer data.

## Finish
Report as `passed / failed / skipped per TC`. Update `state.json` with `tested.<env>` = `{at, passed, failed}`
and the stage `tested-<env>` when everything passed. Next step:
- after local passes: `commit-draft`, then the user commits, pushes and deploys, then `api-test dev`
- after all target environments pass: `api-doc`
