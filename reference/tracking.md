# Tracking (details) — only when the user asks about time, logs or switching tracking

- **Timing is automatic.** Plugin hooks (`hooks/hooks.json` → `scripts/hooks/track.ps1`) timestamp every user prompt
  and every end of turn, and append an entry to `<ticket>/timing.json` whenever `state.json.stage` changes
  (wall minutes, active minutes, user turns). At `logged` they also write a ticket summary to the plugin log.
  Costs no tokens. You only keep `stage` up to date.
- **Show times:** `scripts/stage-timer.ps1 show -Ticket <KEY>` — show its table as is; never compute times yourself.
- **Switches:** `scripts/tracking.ps1 status | on | off [-Feature timing|feedback] [-Project]`
  ("tắt/bật tracking").
- **Feedback log (manual):** only when the user asks to record something about the plugin:
  `scripts/plugin-log.ps1 add -Ticket <KEY> -Skill <skill> -Type correction|rule-break|stuck|good -Note "<one line>"`.
  Overview: `plugin-log.ps1 summary`. Ticket ended without `work-log`: `plugin-log.ps1 ticket-summary -Ticket <KEY>`.
  Never put code, customer data or secrets in notes.
