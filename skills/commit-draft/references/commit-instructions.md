# Commit message rules

> If the project has its own commit rule (`paths.commitRules` in `.dev-flow.json`), that file wins where they differ.

You must strictly follow the Conventional Commits specification.
Format: <type>(<scope>): <short description>

Allowed types: feat, fix, docs, style, refactor, perf, test, chore, ci.
- The entire commit message (subject and body) must be written in English, regardless of what
  language the rest of the conversation is in.
- The subject line must be in the imperative mood (e.g., "add" not "added").
- Do not end the subject line with a period.
- Limit the first line to 50 characters.
- Use bullet points for the body if there are multiple changes.
- Do not include any name (author, co-author, or attribution line) anywhere in the commit message.
- Never run `git commit` or `git push` yourself. Stage the relevant files (`git add`) and draft the commit message per the rules above, then stop and hand it to the user — committing and pushing are the user's action alone, every time, even if asked to "commit" the changes.