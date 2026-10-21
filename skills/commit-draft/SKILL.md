---
name: commit-draft
description: Stage the ticket's changes and draft a Conventional Commits message in English (type(scope) subject ≤50 chars, imperative, bullet body, no names or attribution) for the user to commit themselves — never runs git commit or git push. Use when the user asks to commit, write a commit message, or after code-review when changes are ready.
argument-hint: "[<JIRA-KEY>]"
---

# Commit draft

Read **`references/commit-instructions.md`**. These are the rules. If `paths.commitRules` is set in
`.dev-flow.json`, read that file too. Where the two differ, the project's file wins.

## Hard rule
**Never run `git commit` or `git push`.** This applies even if the user says "commit". Committing and
pushing are always the user's action. This skill stops after `git add` and the drafted message.

## Steps
1. Run `git status` and `git diff`. Separate the ticket's changes from unrelated ones. Never stage:
   - secrets or personal config (`config_swagger.json`, `credentials.json`, `.jira/config.json`)
   - caches (`.dev-flow/cache/`, `.jira/cache/`)
   - local scratch files

   If such a file shows up as untracked, suggest a `.gitignore` entry.
2. Show the list of files you intend to stage, and ask if unsure. Then `git add` exactly those files.
3. Draft the message:
   - `<type>(<scope>): <short description>`. Types: feat, fix, docs, style, refactor, perf, test, chore, ci.
   - English only. Imperative mood. No trailing period. First line ≤ 50 characters (count it).
   - Scope: the module or area. Put the ticket key in the body (e.g. `Refs: PROJ-123`), unless the project's rule says otherwise.
   - Body: bullet points when there is more than one change.
   - **No names, co-author or attribution lines.**
4. If the changes mix unrelated concerns, propose splitting them into several commits, each with its own file list and message.
5. Output the message in a code block, plus the command for the user to run:
   ```
   git commit -F <file>      # or: git commit -m "<subject>" -m "<body>"
   ```
6. If a ticket workspace exists, note the drafted commit in `implementation-notes.md`.
