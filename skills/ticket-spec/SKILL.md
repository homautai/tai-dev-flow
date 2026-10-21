---
name: ticket-spec
description: Turn a fetched and clarified ticket into an implementation spec (tickets/KEY/spec.md) with scope, acceptance criteria, API contract, DB changes, implementation plan and numbered test cases, then wait for the user's approval. Use after ticket-clarify or when the user asks to write the spec / viết spec / viết ticket thành md.
argument-hint: "<JIRA-KEY>"
---

# Ticket spec

Read `<plugin-root>/reference/workflow.md` first. Inputs: `ticket.md`, `questions.md`, the rules index, and the code explored during clarification.

0. **Investigation (bugs, performance, unclear root cause).** If the fix depends on facts nobody knows
   yet (where the time goes, which query is slow, why a value is wrong), first propose a short
   investigation plan: what to read, measure or run, where, and roughly how long. **Run it only after the
   user agrees.** Record the findings in the spec's "Investigation" section, then design the change from
   them. Keep it focused on the ticket; report anything else you find as a suggestion.
1. Write `spec.md` from `<plugin-root>/templates/spec.md` in `language.workNotes`.
   - Every AC maps to at least one test case (TC#). Every TC states method, endpoint, input, expected
     status, expected result, and the environment(s) it runs on.
   - Include negative TCs: validation (400), not found (404), conflict (409), forbidden (403) where relevant.
   - API URLs, verbs and response shapes follow the project's rules (`paths.rules`) and existing endpoints.
   - Cite decisions as D# instead of repeating the reasoning.
   - The implementation plan names concrete layers and files, following existing patterns in the codebase.
   - **Other repos:** if part of the change lives in another repo (e.g. a database repo) or is owned by
     someone else, list it in "Changes in other repos" with the proposed change (e.g. the SQL), the owner and
     the reviewer. This repo's `implement` covers only this repo. The other part is done by running the
     plugin in that repo with the same ticket key, or by its owner.
2. Keep it as short as the ticket allows. A small ticket gets a short spec. Do not pad sections.
3. Show the spec, highlighting:
   - assumptions you made that the user did not decide explicitly
   - open questions still unresolved
4. **Gate:** wait for explicit approval. On changes, edit the spec and show the diff.
5. On approval, set `> Status: APPROVED (<date>)` in the spec and `specApproved: true` and stage
   `specified` in `state.json`, then suggest `implement`. Also propose a branch name in the form
   `feature/<KEY>-<short-kebab-name>` (unless the project's rules say otherwise), and store the agreed
   name in `state.json.branch`.
