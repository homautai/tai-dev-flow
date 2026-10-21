---
name: api-doc
description: Write the FE-facing API comment for a ticket into the project's API comments file, following the plugin's API documentation rules — scope, every endpoint with full URL, annotated request (enum value tables), real response, exact error conditions, Notes for FE, shared lookup endpoints — as a draft the user posts to Jira themselves. Use after api-test passes, or when the user asks for API comments / API doc for FE.
argument-hint: "<JIRA-KEY>"
---

# API doc for FE

> **Timer:** first run `stage-timer.ps1 start -Ticket <KEY> -Stage documented`, and as the very last step
> `stage-timer.ps1 finish -Ticket <KEY> -UserTurns <n>` (workflow.md §3, Timing). Never write times by hand.


Read first:
- `<plugin-root>/reference/workflow.md`
- **`references/api-documentation.md`**. These are the rules (§1–§6). This file only describes the steps.
  If `paths.apiDocRules` is set in `.dev-flow.json`, read that file too. Where the two differ, the project's file wins.

An API comment is a **deliverable of the ticket** (§1). A ticket that adds or changes an endpoint is not done until this is written.

## Preconditions (§4)
- Every endpoint must have a logged self-test in the API test logs. If one is missing, run `api-test` and log it **before** drafting, not after.
- Field names, types, defaults and enum values come from the **current code** (request/response models, commands, validators, enums as they stand now) plus the logged test results. Never take them from the ticket's AC text or from memory.

## Steps
1. List the endpoints this ticket adds or changes, from the spec and the diff.
2. Check which shared lookup or reference-data endpoints the screen needs: dropdown sources, enum lists and similar (§2).
   - If one is already documented under its own shared heading, link to it.
   - If not, document it under its own heading. Do not tie it to this ticket's number.
3. Read the request/response models, validators, enums, handlers and the controller/route for each endpoint.
4. Write the section in **English** (§3), in the order §2 requires, using
   `<plugin-root>/templates/api-doc-section.md`:
   1. **Scope**: what is delivered and what is explicitly **not** (deferred or blocked, with the ticket key).
   2. The **"APIs this ticket needs"** table.
   3. Per endpoint:
      - method + full URL with query params
      - **request** JSON with inline annotations (required/optional, default, units). Every enum-backed field gets its value table (e.g. `0=Draft, 1=Submitted`).
      - **response** shaped exactly like the real one, taken from the passing test in the log. Trim long arrays and anonymise real personal data.
      - **errors**: every non-200 status with the **exact** triggering condition (which field, which rule), from the validators and handlers.
      - **Notes for FE**: full-replace vs partial-update, silently ignored fields, mode-dependent fields, rules split across endpoints.
5. Where to write (§6): append to `apiTest.apiDocFile` under `## <KEY> — <title>`.
   - If the ticket's contract was revised later, add a **dated sub-entry**. Do not rewrite history.
   - Flag a breaking change explicitly.
6. Self-check against the §2 list before finishing. Every endpoint must have all six parts.

## Finish (§5)
- This is a **draft**. Never call a Jira tool to post it, unless the user explicitly asks for that in the same turn.
- Tell the user the section heading and file, so they can review and post it.
- Update `state.json` to `documented`, then suggest `work-log`.
