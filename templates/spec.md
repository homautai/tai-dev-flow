# {{KEY}} — {{Title}}

> Status: DRAFT | APPROVED ({{date}})
> Ticket: [ticket.md](ticket.md) · Decisions: [questions.md](questions.md)

## 1. Summary
<2–4 sentences: what changes and why.>

## 1a. Investigation (only for bugs / performance / unclear root cause)
| What was checked | How / where | Finding |
|---|---|---|
| | | |
**Root cause:** <one or two sentences, or "not confirmed — see risks">

## 2. Scope
**In scope**
-
**Out of scope**
-

## 3. Acceptance criteria
| AC | From ticket | How it is verified (test case IDs) |
|---|---|---|
| AC1 | | TC1, TC2 |

## 4. API contract
| # | Method | URL | Purpose | Auth / policy | New / changed |
|---|---|---|---|---|---|
| 1 | | | | | |

### 4.x `<METHOD> <URL>`
**Request**
```jsonc
{}
```
**Response <code>**
```jsonc
{}
```
**Errors:** 400 (validation: ...), 404 (...), 409 (...)

## 5. Data / DB changes
- Tables / columns / migrations / seed data / stored procedures:

## 5a. Changes in other repos (only if the ticket spans repos)
| Repo | File / object | Proposed change | Owner / reviewer | Status |
|---|---|---|---|---|
| | | (SQL or code proposal, or "see below") | | proposed / PR open / merged |

## 6. Implementation plan
| Step | Layer / files | Change |
|---|---|---|
| 1 | | |

## 7. Test cases
| TC | Endpoint | Scenario | Input (body / params) | Expected status | Expected result | Env |
|---|---|---|---|---|---|---|
| TC1 | | Happy path | | 200 | | local, dev |
| TC2 | | Validation error | | 400 | | local |

## 8. Risks & open questions
- OQ#:
