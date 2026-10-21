---
name: ticket-clarify
description: Interview the user about a fetched ticket until every decision needed for the spec is made — business rules, API contract, validation, auth/tenant, DB, edge cases, FE impact — recording decisions (D#) and open questions (OQ#) in questions.md. Use after ticket-fetch, when the user says "hỏi tôi", "grill", "clarify", or when a ticket is too vague to spec.
argument-hint: "<JIRA-KEY>"
---

# Ticket clarify (grill)

> **Tracking:** timing is automatic; just update `state.json.stage` when this stage ends. If feedback logging is on,
> log each user correction, rule break or blocker with `plugin-log.ps1 add` (workflow.md §3).


Read `<plugin-root>/reference/workflow.md` first. Inputs: `<tickets>/<KEY>/ticket.md` and any existing `questions.md`.

## Before asking anything: a budget of 6 tool calls, then ask
Questions come first; code reading is only there to make the questions sharper.

- **Hard budget: at most 6 tool calls** (searches + file reads) before the first question. Count them.
  When the budget is used up, **stop and ask**, even mid-thought.
- Spend them on the entry points only: the endpoint/controller, the main handler or service, the entity/table,
  and any earlier ticket folder in the same area. Read only the relevant part of each file.
- **Forbidden in this skill:** sub-agents; following callers or call chains; reading stored procedures,
  SQL functions or infrastructure (timeouts, gRPC/HTTP settings, query plans); anything aimed at finding
  a root cause. If you notice you are asking yourself "why does it fail" or "where is it called from",
  that is investigation: turn it into a question for the user or an `OQ`, and move on.
- **Between questions:** at most 2 targeted lookups to check a specific answer, never a new exploration.

Write what you found under "Answered by reading the code", citing `file:line`. Deeper work goes to the
investigation step of `ticket-spec` and runs only with the user's OK.

## How to ask
- **One question at a time.** Each question includes:
  - why it matters (what changes in the code depending on the answer)
  - the options, with **your recommended answer first** and the reason for it
- Trivial confirmations may be batched: up to 3 yes/no items in one message.
- After each answer, write it to `questions.md` straight away as `D#` (decided) or `OQ#` (open, with who
  can answer it: BA / FE / PO). Use `<plugin-root>/templates/questions.md` the first time.
- If an answer contradicts the ticket or earlier decisions, say so and resolve it before moving on.

## Coverage checklist (work through it; skip items that clearly do not apply)
1. Goal and users: which screen or flow, and who uses it
2. Acceptance criteria: each one testable? Anything implied but not written?
3. API contract: new or changed endpoints, URL and verb conventions from the rules, request/response
   shape, status codes, paging/sorting/filtering
4. Validation and error messages
5. Authorization, policies, multi-tenant isolation
6. Data: tables, columns, migrations, seed data, stored procedures, backfill of existing rows
7. Edge cases: empty, null, duplicates, concurrency, large data, time zones
8. Backward compatibility: breaking changes for FE or other consumers
9. Out of scope: what will **not** be done
10. Testing: which environments, test data needed, anything only a human can verify

## Finish
Stop when the checklist is covered or the user says it is enough. Summarise the decisions (D#) and the
blocking open questions (OQ#), update `state.json` to `clarified`, and suggest `ticket-spec`.
Blocking OQs do not stop the spec. They are carried into it as risks.
