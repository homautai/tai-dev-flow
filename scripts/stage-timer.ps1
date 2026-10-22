#Requires -Version 7
<#
.SYNOPSIS
    Record real start/finish times of a ticket stage in state.json. Never write times by hand.
.EXAMPLE
    pwsh -File stage-timer.ps1 start  -Ticket PROJ-123 -Stage clarified
    pwsh -File stage-timer.ps1 finish -Ticket PROJ-123 -UserTurns 4 -Notes "2 spec revisions"
    pwsh -File stage-timer.ps1 show   -Ticket PROJ-123
#>
param(
    [Parameter(Mandatory=$true, Position=0)][ValidateSet('start','finish','show')][string]$Action,
    [Parameter(Mandatory=$true)][string]$Ticket,
    [string]$Stage,
    [int]$UserTurns = 0,
    [string]$Notes = '',
    [string]$TicketsDir
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
Set-StrictMode -Off

$Ticket = $Ticket.Trim().ToUpper()
if (-not $TicketsDir) {
    $root = Find-ProjectRoot
    if (Get-ProjectConfig -ProjectRoot $root) { $TicketsDir = Get-TicketsDir -ProjectRoot $root }
    else {
        # Not inside a set-up project: look for the ticket in the known workspaces.
        $hit = @(Get-WorkspaceRegistry | Where-Object { Test-Path (Join-Path $_.ticketsDir $Ticket) } | Select-Object -First 1)
        if (-not $hit) { throw "Ticket $Ticket not found: run from the project folder, or set it up with setup-project." }
        $TicketsDir = $hit[0].ticketsDir
    }
}
$dir = Join-Path $TicketsDir $Ticket
$file = Join-Path $dir 'state.json'
if ($Action -eq 'show' -and -not (Test-Path $dir)) { Write-Host "NO_TIMING: no folder for $Ticket."; exit 0 }
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$state = if (Test-Path $file) { Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{ ticket = $Ticket; stage = $null } }
if (-not $state.PSObject.Properties['history']) { $state | Add-Member history @() }
$now = Get-Date

function Save { $state | ConvertTo-Json -Depth 20 | Set-Content -Path $file -Encoding utf8 }
function Set-Prop($obj, $name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

switch ($Action) {
    'start' {
        if (-not $Stage) { throw "-Stage is required for start." }
        $running = $state.PSObject.Properties['running']
        if ($running -and $running.Value) { Write-Host "WARNING: '$($running.Value.stage)' was still running since $($running.Value.startedAt); it is replaced (not recorded)." -ForegroundColor Yellow }
        Set-Prop $state 'running' ([pscustomobject]@{ stage = $Stage; startedAt = $now.ToString('o') })
        Save
        Write-Host "TIMER_STARTED $Ticket $Stage at $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
    }
    'finish' {
        $running = $state.PSObject.Properties['running']
        if (-not $running -or -not $running.Value) { Write-Host "NO_TIMER: nothing running for $Ticket. Nothing recorded." -ForegroundColor Yellow; exit 3 }
        $r = $running.Value
        $start = if ($r.startedAt -is [datetime]) { $r.startedAt } else { [DateTimeOffset]::Parse([string]$r.startedAt).LocalDateTime }
        $minutes = [math]::Round(($now - $start).TotalMinutes, 1)
        $entry = [pscustomobject]@{
            stage = if ($Stage) { $Stage } else { $r.stage }
            startedAt = $r.startedAt; finishedAt = $now.ToString('o'); minutes = $minutes
            userTurns = $UserTurns; notes = $Notes; source = 'timer'
        }
        $state.history = @($state.history) + $entry
        Set-Prop $state 'running' $null
        Save
        Write-Host "TIMER_FINISHED $Ticket $($entry.stage): $minutes min, $UserTurns user turns"
    }
    'show' {
        $timingFile = Join-Path $dir 'timing.json'
        $entries = @()
        if (Test-Path $timingFile) {
            $entries = @((Get-Content $timingFile -Raw | ConvertFrom-Json).entries | Where-Object { $_ } | ForEach-Object {
                [pscustomobject]@{ stage = $_.stage; wall = [double]$_.wallMinutes; active = [double]$_.activeMinutes; turns = [int]$_.userTurns; src = 'auto' } })
        }
        foreach ($h in @($state.history) | Where-Object { $_ -and $_.source -eq 'timer' }) {
            $entries += [pscustomobject]@{ stage = $h.stage; wall = [double]$h.minutes; active = [double]$h.minutes; turns = [int]$h.userTurns; src = 'manual' }
        }
        if (-not $entries.Count) { Write-Host "NO_TIMING: nothing recorded for $Ticket (automatic timing off, or no stage change yet)."; exit 0 }
        Write-Host ('{0,-14} {1,4} {2,9} {3,10} {4,9}' -f 'Stage', 'Runs', 'Wall min', 'Active min', 'UserTurns')
        $tw = 0.0; $ta = 0.0; $tt = 0
        foreach ($name in ($entries.stage | Select-Object -Unique)) {
            $grp = @($entries | Where-Object stage -eq $name); $g = [pscustomobject]@{ Name = $name; Count = $grp.Count }
            $w = ($grp | Measure-Object wall -Sum).Sum; $a = ($grp | Measure-Object active -Sum).Sum; $u = ($grp | Measure-Object turns -Sum).Sum
            $tw += $w; $ta += $a; $tt += $u
            Write-Host ('{0,-14} {1,4} {2,9:N1} {3,10:N1} {4,9}' -f $g.Name, $g.Count, $w, $a, $u)
        }
        Write-Host ('{0,-14} {1,4} {2,9:N1} {3,10:N1} {4,9}' -f 'TOTAL', '', $tw, $ta, $tt)
        Write-Host 'Wall = clock time between stage changes. Active = Claude working + your think time (gaps over 15 min not counted).'
    }
}
