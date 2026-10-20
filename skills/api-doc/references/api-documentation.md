# API documentation rules

> Generic rules for the FE-facing API comment, used across projects.
> If a project has its own API documentation rule (`paths.apiDocRules` in `.dev-flow.json`), that file wins where they differ.
> Examples below use a neutral `orders` / `products` domain. They are illustrations, not real endpoints.

## §1 When an API comment is required
A ticket that adds or changes an endpoint is not done until its API comment is prepared. Code and a
self-test are not enough. The method/URL/body reference is the frontend developer's integration contract.
Treat it as a deliverable of the ticket, not as optional documentation written if there is time left over.

## §2 Required sections
Every API comment contains, in this order:

1. **Scope**: what this pass delivers, and what it explicitly does *not*. Name anything deferred or
   blocked and the ticket it waits on, e.g. "Discount rules not implemented yet, blocked on <KEY>".
2. **Per endpoint:** the HTTP method and the full URL, including path and query parameters,
   e.g. `GET /orders/{id}?include=items`.
3. **Request body**: a realistic JSON example. Annotate every non-obvious field inline: required or
   optional, default value, format, units, limits. Any enum-backed field gets its value table spelled out,
   e.g. `0=Draft, 1=Submitted, 2=Cancelled`. Never make the frontend guess or go read the enum source.
4. **Response body**: a success example shaped exactly like what the endpoint actually returns,
   including the project's response envelope if it has one.
5. **Error responses**: every status other than success, each with the *exact condition* that triggers it.
   Not just "400 on bad input": name the field, the rule, and the message the FE will receive.
6. **Notes for FE**: anything a frontend developer would get wrong by guessing. For example:
   - full-replace vs partial-update semantics for a nested section
   - a field that is silently ignored under some condition
   - a field that only appears for one mode or parameter value
   - a rule that is split across two endpoints, such as status changes living outside the main update endpoint
   - paging, sorting and filtering behaviour
   - empty array vs `null`

**Shared endpoints.** Before treating the comment as complete, check whether the screen depends on
shared lookup or reference-data endpoints: dropdown sources, enum lists, user or permission info, and
similar. These are easy to miss because they are not the ticket's own new endpoint, but the FE cannot
build the screen without them. If more than one ticket's screen depends on one, document it once under
its own heading, not tied to a ticket number, and link to it, rather than duplicating it into each ticket's section.

## §3 Language
Write the comment entirely in English, whatever language the conversation is in. It is read by the
frontend developer, not by whoever asked for it.

## §4 Source of truth
Every field name, type, default and enum value comes from the **current code** (request/response
models, commands, validators, enums as they stand right now) and from results already recorded in the
API test logs (`apiTest.logFiles`). Never take them from the ticket's original AC text, or from memory of
what the shape "should" be. If a self-test for the endpoint has not been logged yet, run and log it with
the `api-test` skill **before** drafting the comment, not after.

## §5 Never posted automatically
An API comment is a draft for the user to review and post themselves. Do not call any Jira, Bitbucket
or other tool to post it, unless the user explicitly asks for that in the same turn. Preparing the
content and posting it are two separate steps. Only the first is done by default.

## §6 Where it lives
Append every API comment to `apiTest.apiDocFile` (default `docs/API_test/API-Comments.md`) under its own
`## <KEY> — <title>` heading. If the same ticket's contract is revised later, add a **dated sub-entry**
and flag breaking changes. Keep one running file per project, not one file per ticket, so every endpoint
contract the FE needs is in a single place.
