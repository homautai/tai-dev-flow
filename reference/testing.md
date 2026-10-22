# Local testing and user-verified results (details)

## Local environment
`.dev-flow.json` → `testing`:
- `localEnvironment: "user"` (default): the user starts databases and apps. Before a test step show the
  `prerequisites` checklist and **wait** until the user says it is ready.
- `localEnvironment: "agent"`: you may run `startCommands`.
- Databases: see core rules (never create/drop; scripts only with OK).

## User-verified results
When the user says they tested something themselves ("tôi đã test xong", "verified", "all good"):
1. Ask once, only for what is missing: environment, which cases (or "all"), per-case result if not all PASS, and
   whether it was on the current code (after `codeChangedAt`). Accept short answers.
2. Do not re-run those cases; do not mark more than the user confirmed.
3. Record it: in the environment's API test log (or `review.md` / `implementation-notes.md` when there is no API log),
   an entry `Verified by <user> (manual)` with date/time, environment, cases, results, notes; in `state.json`,
   `tested.<env> = { at, by: "user", passed, failed, cases, notes }`, then advance the stage and close the related
   review finding as if you had run the tests.
4. Tested on older code: record it, keep the environment stale, say so.
