---
name: ticket-fetch
description: Fetch a Jira ticket into the ticket workspace (tickets/KEY/ticket.md) and start its state file. Use when the user gives a Jira key (e.g. PROJ-123) and wants to start, read or pick up that ticket, or when dev-flow starts a new ticket.
argument-hint: "<JIRA-KEY>"
---

# Ticket fetch

> **Timer:** first run `stage-timer.ps1 start -Ticket <KEY> -Stage fetched`, and as the very last step
> `stage-timer.ps1 finish -Ticket <KEY> -UserTurns <n>` (workflow.md §3, Timing). Never write times by hand.


Read `<plugin-root>/reference/workflow.md` first.

1. Normalise the key to upper case. Resolve the ticket folder `<paths.tickets>/<KEY>/`.
2. If `state.json` already exists, report the current stage and ask: refetch (keeps the other files), or
   continue with `dev-flow`? On refetch, compare the new `ticket.md` with the previous one. If the
   description, AC or comments changed after the spec was approved, list the changes and flag the spec
   sections and test cases they affect.
3. Fetch the ticket:
   - If a Jira MCP tool is connected, you may use it to get the issue (fields, description, comments,
     subtasks, links) and write `ticket.md` in the same layout the script produces.
   - Otherwise run from the project root:
     `pwsh -NoProfile -File "<plugin-root>/scripts/fetch-ticket.ps1" <KEY> -OutDir "<paths.tickets>/<KEY>"`
   - On a credentials error, point the user to `setup-project` step 3. Do not ask for the token.
4. Read `ticket.md`. If there is a parent, epic or "blocks / is blocked by" link that the ticket clearly
   depends on, list them and ask whether to fetch them too. Fetched linked tickets go into the cache, not
   into this ticket's folder.
5. Write `state.json` with stage `fetched` (schema in workflow.md).
6. Reply with:
   - a summary of at most 5 lines: what is being asked, who reported it, status
   - the acceptance criteria as written, or "none written" if there are none
   - gaps and ambiguities you already see, as a bullet list
   - next step: "Start clarification now?" (`ticket-clarify`)
