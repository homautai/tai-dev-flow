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
    $rel = Get-OptionalProperty (Get-OptionalProperty (Get-ProjectConfig -ProjectRoot $root) 'paths') 'tickets'
    if (-not $rel) { $rel = 'docs/tickets' }
    $TicketsDir = Join-Path $root $rel
}
$dir = Join-Path $TicketsDir $Ticket
$file = Join-Path $dir 'state.json'
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
        $rows = @($state.history) | Where-Object { $_ } | Group-Object stage | ForEach-Object {
            $timed = @($_.Group | Where-Object { $_.source -eq 'timer' })
            [pscustomobject]@{
                Stage = $_.Name; Runs = $_.Count
                Minutes = [math]::Round((($timed | Measure-Object minutes -Sum).Sum), 1)
                UserTurns = ($timed | Measure-Object userTurns -Sum).Sum
                Measured = if ($timed.Count -eq $_.Count) { 'yes' } elseif ($timed.Count -eq 0) { 'no (approx/missing)' } else { 'partly' }
            }
        }
        Write-Host ('{0,-14} {1,4} {2,8} {3,9}  {4}' -f 'Stage', 'Runs', 'Minutes', 'UserTurns', 'Measured')
        foreach ($row in $rows) {
            Write-Host ('{0,-14} {1,4} {2,8} {3,9}  {4}' -f $row.Stage, $row.Runs, $row.Minutes, $row.UserTurns, $row.Measured)
        }
        $total = ($rows | Measure-Object Minutes -Sum).Sum
        Write-Host ("TOTAL measured: {0} min ({1:N1} h). Rows with Measured != yes were not timed by this script." -f $total, ($total / 60))
        $running = $state.PSObject.Properties['running']
        if ($running -and $running.Value) { Write-Host "RUNNING: $($running.Value.stage) since $($running.Value.startedAt)" }
    }
}
