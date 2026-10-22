---
name: implement
description: Implement an approved ticket spec following the project's own coding rules — tests first where the project has a test project, build and run tests, record files changed and deviations in implementation-notes.md, then hand over to code-review. Use when the user says implement / code / làm ticket after the spec is approved.
argument-hint: "<JIRA-KEY>"
---

# Implement

Read `<plugin-root>/reference/core.md` first, and `<plugin-root>/reference/testing.md` before running tests.

## Preconditions
- `spec.md` exists and `state.json.specApproved` is `true`. If not, stop and offer `ticket-spec`.
- Load the rules: the `paths.rules` entry file **and every file it lists, in full**. The rules belong to
  the project, not to this plugin. Different projects have different rules.
- Check the working tree (`git status`). If it has unrelated changes, ask before touching anything.
  Suggest the branch from `state.json.branch`, but create or switch branches only with the user's OK.

## Loop, per implementation-plan step
1. Find the closest existing example of the same kind of change in the codebase and follow its patterns.
2. If the project has a test project (or `tests.unitTestCommand` is set), write or extend the tests
   for this step first, and run them to see them fail for the expected reason.
3. Make the change. Keep the diff focused on the spec. No drive-by refactors; list those as suggestions instead.
4. Build (`tests.buildCommand` or the detected command) and run the relevant tests.
5. Fix until both are green. If the spec is wrong or impossible, **stop and ask**. Do not silently change the
   contract. Record agreed changes as deviations and update `spec.md`.

## Local testing
Follow `testing` in `.dev-flow.json` (`<plugin-root>/reference/testing.md`): if the user runs the environment, list the prerequisites
and wait for "ready". Cases the user tested themselves are recorded as user-verified. Set `state.json.codeChangedAt`
whenever you change the ticket's code.

## Database
- Add migrations, seed data and SQL scripts the way the project already does.
- List anything that must be run manually on dev/qa in `implementation-notes.md`.

## Finish
1. Write `implementation-notes.md` from `<plugin-root>/templates/implementation-notes.md`: files changed, deviations, scripts to run on other
   environments, rules self-check.
2. Update `state.json` to `implemented`.
3. Run the `code-review` skill on the diff. **Gate:** show the findings and ask which to fix. Fix the
   agreed ones, and list the rest in `implementation-notes.md`.
4. **Never run `git commit` or `git push`.** When the changes are ready, use `commit-draft`. It stages the
   files and drafts a Conventional Commits message for the user to commit themselves.
5. Next step: `api-test local`.
