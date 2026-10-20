---
name: ticket-clarify
description: Interview the user about a fetched ticket until every decision needed for the spec is made — business rules, API contract, validation, auth/tenant, DB, edge cases, FE impact — recording decisions (D#) and open questions (OQ#) in questions.md. Use after ticket-fetch, when the user says "hỏi tôi", "grill", "clarify", or when a ticket is too vague to spec.
argument-hint: "<JIRA-KEY>"
---

# Ticket clarify (grill)

Read `<plugin-root>/reference/workflow.md` first. Inputs: `<tickets>/<KEY>/ticket.md` and any existing `questions.md`.

## Before asking anything: a quick scan, not an investigation
Do a **short, time-boxed scan** so you do not ask what the code answers at a glance:
- Locate the entry points only: the controller/endpoint, handler or service, entity/table, and any earlier
  ticket folder in the same area. Use search (grep/glob). Read **at most ~10 files**, and only the relevant parts.
- Aim for **a few minutes**. Then start asking, even if you are not done exploring.
- **Do not** spawn sub-agents, trace call chains end to end, inspect infrastructure (timeouts, gRPC/HTTP
  settings, query plans), or try to find a root cause. That is the investigation step of `ticket-spec`,
  and it is done only with the user's OK.

Write what you found under "Answered by reading the code", citing `file:line`. Anything that needs deeper
digging becomes a question ("Should the spec include an investigation of X?") or an `OQ`.

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
