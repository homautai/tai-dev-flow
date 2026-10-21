---
name: work-log
description: Log time spent on a Jira ticket after confirming duration, start time and comment with the user. Use when the user asks to log work / logwork / ghi giờ for a ticket, or at the end of dev-flow.
argument-hint: "<JIRA-KEY> [time e.g. 2h30m] [comment]"
disable-model-invocation: true
---

# Work log

This logs time on **one Jira ticket**. For a whole month in Timekeeper, use `timekeeper-log` instead.

Read `<plugin-root>/reference/workflow.md` first (`<plugin-root>` = two folders above this file).

1. Collect the details:
   - **Time:** from the argument, or ask. You may suggest the measured total from `stage-timer.ps1 show`
     (wall-clock, includes waiting), rounded to 15 minutes. If stages were not measured, say so and let the user
     give the time; never present an estimate as measured.
   - **Started:** default now. Accept "today 9am"-style input and convert it to Jira's format
     `yyyy-MM-ddTHH:mm:ss.000+0700` (using the user's time zone).
   - **Comment:** default to a one-line summary of the stages done, e.g. "Clarify + spec + implement + API test local/dev".
2. Show the exact entry and wait for an explicit **yes**. A worklog is visible to the team and to billing.
3. Run `pwsh -NoProfile -File "<plugin-root>/scripts/logwork-jira.ps1" <KEY> "<time>" "<comment>" "<started>"`.
4. Report the worklog id, and set the stage to `logged` in `state.json` if a ticket workspace exists.
