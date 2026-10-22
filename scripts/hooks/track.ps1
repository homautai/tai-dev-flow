<#
.SYNOPSIS
    Automatic stage timing (Claude Code hook). Runs on UserPromptSubmit (-Event prompt) and Stop (-Event stop).
.DESCRIPTION
    - Counts user prompts and active time per session (~/.dev-flow/tracking/session-<id>.json).
      Active time = time Claude works in a turn + the user's think time between turns, capped at 15 minutes,
      so overnight breaks do not count.
    - Scans <tickets>/*/state.json of the current project. When a ticket's "stage" changes, appends an entry
      to <tickets>/<KEY>/timing.json: stage, startedAt, finishedAt, wallMinutes, activeMinutes, userTurns.
    - When a ticket reaches "logged", writes the ticket summary to the plugin log.
    Never blocks Claude: every error is swallowed and the script always exits 0 without output.
    Disabled by tracking.autoTiming = false (see tracking.ps1).
#>
param([ValidateSet('prompt','stop')][string]$Event = 'stop')

$ErrorActionPreference = 'Stop'
try {
    $raw = [Console]::In.ReadToEnd()
    $in = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    $cwd = if ($in.cwd) { [string]$in.cwd } else { (Get-Location).Path }
    $sessionId = if ($in.session_id) { [string]$in.session_id } else { 'default' }

    . (Join-Path $PSScriptRoot '../lib/Common.ps1')
    Set-StrictMode -Off
    $root = Find-ProjectRoot -Start $cwd
    if (-not (Get-TrackingSettings -ProjectRoot $root).autoTiming) { exit 0 }

    $now = Get-Date
    $idleCapSeconds = 15 * 60          # user think time counted at most 15 min per gap
    $turnCapSeconds = 120 * 60         # one Claude turn counted at most 2 h

    # --- session counters -------------------------------------------------
    $trackDir = Join-Path $HOME '.dev-flow/tracking'
    if (-not (Test-Path $trackDir)) { New-Item -ItemType Directory -Path $trackDir -Force | Out-Null }
    $safeId = ($sessionId -replace '[^\w-]', '_')
    $sessFile = Join-Path $trackDir "session-$safeId.json"
    $sess = if (Test-Path $sessFile) { Get-Content $sessFile -Raw | ConvertFrom-Json } else {
        [pscustomobject]@{ prompts = 0; activeSeconds = 0.0; lastPromptAt = $null; lastStopAt = $null } }
    function ToDate($v) { if ($null -eq $v -or $v -eq '') { return $null }; if ($v -is [datetime]) { return $v }; return [DateTimeOffset]::Parse([string]$v).LocalDateTime }

    # Start of the current turn (and active time at that moment), captured before the counters move on.
    $turnStartedAt = if ($Event -eq 'prompt') { $now } else { ToDate $sess.lastPromptAt }
    $activeAtTurnStart = [double]$sess.activeSeconds

    if ($Event -eq 'prompt') {
        $pending = ToDate $sess.lastPromptAt
        $lastStop = ToDate $sess.lastStopAt
        if ($pending) {
            # Previous turn never ended (user pressed Esc: no Stop hook). Count it at most like an idle gap.
            $sess.activeSeconds = [double]$sess.activeSeconds + [math]::Min([math]::Max(0, ($now - $pending).TotalSeconds), $idleCapSeconds)
        }
        elseif ($lastStop) { $sess.activeSeconds = [double]$sess.activeSeconds + [math]::Min(($now - $lastStop).TotalSeconds, $idleCapSeconds) }
        $activeAtTurnStart = [double]$sess.activeSeconds
        $sess.prompts = [int]$sess.prompts + 1
        $sess.lastPromptAt = $now.ToString('o')
    } else {
        $lastPrompt = ToDate $sess.lastPromptAt
        if ($lastPrompt) { $sess.activeSeconds = [double]$sess.activeSeconds + [math]::Min([math]::Max(0, ($now - $lastPrompt).TotalSeconds), $turnCapSeconds) }
        $sess.lastStopAt = $now.ToString('o')
        $sess.lastPromptAt = $null   # this turn is accounted for
    }
    $sess | ConvertTo-Json | Set-Content $sessFile -Encoding utf8

    # --- stage transitions (checked at the end of every turn and before every prompt) ----------
    # Ticket folders to scan: the current project's; if Claude is outside any set-up project (it moved to another
    # folder), every workspace used before, so stage changes are still recorded.
    $dirs = @()
    if (Get-ProjectConfig -ProjectRoot $root) { $dirs += Get-TicketsDir -ProjectRoot $root }
    else { $dirs += @(Get-WorkspaceRegistry | ForEach-Object { $_.ticketsDir }) }
    $dirs = @($dirs | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique)
    if (-not $dirs.Count) { exit 0 }

    $stateFiles = foreach ($d in $dirs) { Get-ChildItem -Path $d -Filter 'state.json' -Recurse -Depth 1 -ErrorAction SilentlyContinue }
    foreach ($stateFile in $stateFiles) {
        $ticketDir = $stateFile.DirectoryName
        $timingFile = Join-Path $ticketDir 'timing.json'
        $timing = if (Test-Path $timingFile) { Get-Content $timingFile -Raw | ConvertFrom-Json } else { $null }
        # Skip tickets not touched since our last look
        if ($timing -and $timing.checkedAt -and $stateFile.LastWriteTime -le (ToDate $timing.checkedAt)) { continue }

        $state = try { Get-Content $stateFile.FullName -Raw | ConvertFrom-Json } catch { $null }
        if (-not $state) { continue }
        $stage = [string]$state.stage
        $key = Split-Path -Leaf $ticketDir

        if (-not $timing -and $turnStartedAt -and $stateFile.LastWriteTime -lt $turnStartedAt.AddSeconds(-2)) {
            # Ticket existed before tracking saw it (older work, or tracking just turned on): take a baseline, record nothing.
            $baseline = [pscustomobject]@{ ticket = (Split-Path -Leaf $ticketDir); lastStage = [string]$state.stage; lastAt = $now.ToString('o')
                                           activeAtLast = [double]$sess.activeSeconds; promptsAtLast = [int]$sess.prompts
                                           sessionAtLast = $sessionId; entries = @(); checkedAt = $now.ToString('o'); baselineOnly = $true }
            $baseline | ConvertTo-Json -Depth 10 | Set-Content $timingFile -Encoding utf8
            continue
        }
        if (-not $timing) {
            # First sight of this ticket: the stage that just finished started with this turn.
            $start = if ($turnStartedAt) { $turnStartedAt } else { $stateFile.CreationTime }
            $timing = [pscustomobject]@{ ticket = $key; lastStage = $null; lastAt = $start.ToString('o')
                                         activeAtLast = $activeAtTurnStart; promptsAtLast = [math]::Max(0, [int]$sess.prompts - 1)
                                         sessionAtLast = $sessionId; entries = @(); checkedAt = $null }
        }

        if ($stage -and $stage -ne $timing.lastStage) {
            $from = ToDate $timing.lastAt
            $sameSession = ($timing.sessionAtLast -eq $sessionId)
            $active = if ($sameSession) { [double]$sess.activeSeconds - [double]$timing.activeAtLast } else { [double]$sess.activeSeconds }
            $active = [math]::Min($active, ($now - $from).TotalSeconds)   # active can never exceed wall-clock
            $turns = if ($sameSession) { [int]$sess.prompts - [int]$timing.promptsAtLast } else { [int]$sess.prompts }
            $entry = [pscustomobject]@{
                stage = $stage; startedAt = $from.ToString('o'); finishedAt = $now.ToString('o')
                wallMinutes = [math]::Round(($now - $from).TotalMinutes, 1)
                activeMinutes = [math]::Round([math]::Max(0, $active) / 60, 1)
                userTurns = [math]::Max(0, $turns); source = 'auto'
            }
            $timing.entries = @($timing.entries) + $entry
            $timing.lastStage = $stage; $timing.lastAt = $now.ToString('o')
            $timing.activeAtLast = [double]$sess.activeSeconds; $timing.promptsAtLast = [int]$sess.prompts; $timing.sessionAtLast = $sessionId

            if ($stage -eq 'logged' -and (Get-TrackingSettings -ProjectRoot $root).feedbackLog) {
                $timing.checkedAt = $now.ToString('o')
                $timing | ConvertTo-Json -Depth 10 | Set-Content $timingFile -Encoding utf8
                Push-Location $root
                try { & (Join-Path $PSScriptRoot '../plugin-log.ps1') ticket-summary -Ticket $key -TicketsDir (Split-Path -Parent $ticketDir) *> $null } catch { } finally { Pop-Location }
            }
        }
        $timing.checkedAt = $now.ToString('o')
        $timing | ConvertTo-Json -Depth 10 | Set-Content $timingFile -Encoding utf8
    }
} catch {
    # Never disturb the session. Leave a trace for debugging only.
    try { Add-Content -Path (Join-Path $HOME '.dev-flow/tracking/errors.log') -Value "$(Get-Date -Format o) $Event $($_.Exception.Message)" } catch { }
}
exit 0
