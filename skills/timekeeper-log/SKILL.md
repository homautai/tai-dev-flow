---
name: timekeeper-log
description: Log a whole month (or date range) of work to Timekeeper — find the Jira tickets the user was assigned or logged work on in that period (Jira MCP/Rovo or REST), add leave and public holidays from SRM, split each working day evenly across active tickets to exactly 8h, show the plan, then post the entries through the user's logged-in browser session. Run explicitly with /tai-dev-flow:timekeeper-log yyyy-MM.
argument-hint: "<yyyy-MM> | <yyyy-MM-dd> <yyyy-MM-dd>"
disable-model-invocation: true
---

# Timekeeper log (monthly)

Read first:
- `<plugin-root>/reference/workflow.md` (`<plugin-root>` = two folders above this file). §5 Secrets applies.
- `references/browser-snippets.md`: the in-page JavaScript used for SRM and Timekeeper.

Personal config: `~/.dev-flow/timekeeper.json` (template `<plugin-root>/templates/timekeeper.template.json`).
It holds URLs, the user's Timekeeper user id, customer/reporting/activity codes, and the **ticket sources**:
each source has a date range, a Jira site, a JQL, codes, a description format and meetings.
It holds no tokens. If the file is missing, create it from the template with the user before anything else.
Inspect `~/.dev-flow/credentials.json` only with `scripts/show-config.ps1`.

Working folder for this run: `~/.dev-flow/timekeeper/<period>/` (plan files, chunks). History of past runs:
`~/.dev-flow/timekeeper/history.md`.

## 1. Period
Parse the argument: `2026-09` → 2026-09-01..2026-09-30, or an explicit start/end. With no argument, use
the previous month. Read `history.md`. If it does not exist yet, ask whether the user has an earlier
history (e.g. notes from a previous tool) to paste into it. If this period, or part of it, was already posted,
say so and ask before going on. Step 5 also checks Timekeeper itself, so history is a hint, not the only guard.

## 2. Tickets for the period (per source overlapping the period)
Criterion: tickets **assigned to the user during the period, or with a worklog by the user in the period**.
That is the source's `jql`, with `{start}`/`{end}` filled with the overlap of period and source range.

Get them in this order, per source:
1. **Jira MCP (Atlassian Rovo).** If a Jira MCP tool can reach the source's site (`rovoCloudId` set, or
   discoverable via its accessible-resources tool), run the JQL with fields
   `summary, issuetype, status, created, resolutiondate, parent, assignee`. Results can be large. Page
   through them and keep only those fields.
2. **REST script.** Otherwise run
   `pwsh -NoProfile -File "<plugin-root>/scripts/fetch-month-tickets.ps1" -Period <yyyy-MM> -OutFile ~/.dev-flow/timekeeper/<period>/tickets.json`.
   It uses `~/.dev-flow/credentials.json`, including `atlassian.sites.<host>` for a second Jira site.
3. **Paste.** If neither can reach the site, ask the user to paste the list: key, summary, type, status, created, resolved.

**Optional cross-check with Rovo AI.** If the user wants it and the Rovo `search` tool is available, ask it
in natural language, e.g. "Which <project> tickets did I work on in September 2026?". List any ticket it
returns that the JQL missed, and let the user decide on each. Rovo's answer is never the only source,
because it is not deterministic.

## 3. Review the ticket list with the user
Apply the source's rules, then show one table (key, type, status, created, resolved, keep?/reason):
- `preferBackendSubtask`: log on the user's BE sub-task. Fall back to the parent Bug/Task/Story only when
  the user has no BE sub-task under it.
- Drop the source's `skip` items (e.g. FE/QA sub-tasks, stories in analysis, To Do items), sub-tasks
  assigned to others, and old tickets that were only bulk-closed in the period.

For each kept ticket, set its active window:
- `activeFrom` = the later of `created` and the period start
- `activeTo` = `resolved`, if it falls in the period; otherwise the period end

The user can edit the windows, add or remove tickets, or set `activityTypeId` (e.g. 6 = Code Review).

## 4. Leave and public holidays (SRM)
Use the browser (see "Browser" below) on `srm.url`. The user must already be logged in. Run the SRM
snippet from `references/browser-snippets.md`. It reads the token from `localStorage` **inside the page**,
so the token never leaves the browser.
- Approved and pending requests (status 1, 2, 3). Ignore `srm.ignoreLeaveTypes` (Work From Home).
- Annual and sick leave become leave hours: full day = 8, AM/PM = 4.
- Holidays in the period become public holidays, unless the user says they worked that day.

Show the list and confirm it. Pending leave is included only if the user says so.

## 5. Already in Timekeeper?
Open `timekeeper.url` (the user logs in with Microsoft; **never type passwords**). Run the totals
snippet for the period. If some days already have hours, find out which, and add them to `skipDates`.
Never log a day twice.

## 6. Plan
Write `~/.dev-flow/timekeeper/<period>/plan-input.json` (format in the header of `plan-timekeeper.ps1`), then run:
```
pwsh -NoProfile -File "<plugin-root>/scripts/plan-timekeeper.ps1" -InputFile <plan-input.json> -OutDir ~/.dev-flow/timekeeper/<period>
```
The planner fills every working day (Mon–Fri) to exactly `workday.hours`:
- holiday = Public Holiday
- leave = Paid Leave
- source meetings (e.g. a daily 1h meeting, or a weekly 1h standup on the first working day of the week)
- the rest **split evenly across the tickets active that day**, in 0.5h steps

It fails loudly if any day does not add up.

Show the user, in `language.conversation`:
- the totals (`summary.json`): hours by kind and by ticket, number of working days
- the warnings
- `plan.csv` as a file they can open

**Gate:** wait for an explicit OK, or apply their edits and re-run the planner.

## 7. Post to Timekeeper
In the Timekeeper tab:
1. **Smoke test (first run on a machine, or after `entryFields` changes):** post the first 2 entries only. Then
   reload the period's totals, or open the day in the UI, and confirm with the user that they look right.
2. Post `chunks/chunk-NN.json` one at a time with the post snippet. Each chunk is at most `postChunkSize`
   entries, because the browser JS tool times out after about 45s. Record the returned entry ids.
3. **If a call times out, do NOT re-run it.** Wait, reload the totals, work out what was posted, and post
   only what is missing.
4. Verify: the totals for the period = (working days − skipped days) × 8.

## 8. Wrap up
Append to `~/.dev-flow/timekeeper/history.md`: period, total hours, entry id range, leave and holiday days,
tickets with hours, and assumptions. Reply briefly: hours per month, anything assumed, and where `plan.csv` is.

## Browser
- **Claude app (Cowork or Code):** the built-in browser. Load its skill first, if available.
- **VS Code or another agent:** Playwright MCP (`browser_navigate`, then `browser_evaluate` for the snippets).
  The user logs in in the window that opens.
- **No browser tool:** produce `plan.csv` and the chunk files, and give the user the post snippet to paste
  into the DevTools console on the Timekeeper page, one chunk at a time. Then ask for the printed ids.

Whatever the browser, all SRM and Timekeeper calls run **inside the logged-in page** (`fetch` from page
JS). Do not extract, print or store their tokens.
