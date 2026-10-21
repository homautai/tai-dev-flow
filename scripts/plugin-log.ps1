#Requires -Version 7
<#
.SYNOPSIS
    Plugin evaluation log: one JSON line per event in ~/.dev-flow/plugin-log.jsonl (outside every repo).
.DESCRIPTION
    Records only process metadata (skill, event type, short note). Never code, customer data or secrets;
    token-like strings in notes are masked anyway.
.EXAMPLE
    pwsh -File plugin-log.ps1 add -Ticket PROJ-1 -Skill ticket-clarify -Type correction -Note "user: stop exploring, ask now"
    pwsh -File plugin-log.ps1 ticket-summary -Ticket PROJ-1 -Skipped "test qa: user choice"
    pwsh -File plugin-log.ps1 summary [-Since 2026-10-01] [-Project wec.be]
#>
param(
    [Parameter(Mandatory=$true, Position=0)][ValidateSet('add','ticket-summary','summary')][string]$Action,
    [string]$Ticket,
    [ValidateSet('ticket-fetch','ticket-clarify','ticket-spec','implement','code-review','api-test','api-doc',
                 'commit-draft','work-log','timekeeper-log','setup-project','dev-flow','other')][string]$Skill = 'other',
    [ValidateSet('correction','rule-break','stuck','good')][string]$Type,
    [string]$Note = '',
    [string]$Skipped = '',
    [string]$Since,
    [string]$Project,
    [string]$LogFile = (Join-Path $HOME '.dev-flow/plugin-log.jsonl'),
    [string]$TicketsDir
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
Set-StrictMode -Off

function Get-PluginVersion {
    $p = Join-Path $PSScriptRoot '../.claude-plugin/plugin.json'
    if (Test-Path $p) { return (Get-Content $p -Raw | ConvertFrom-Json).version } else { return 'unknown' }
}
function Hide-Secrets([string]$s) {
    if (-not $s) { return '' }
    $s = $s -replace '(Bearer\s+)?eyJ[\w-]+\.[\w.-]+', '<token>' -replace 'ATATT[\w=-]+', '<token>'
    if ($s.Length -gt 300) { $s = $s.Substring(0, 300) + '…' }
    return $s
}
function Write-Record($obj) {
    $dir = Split-Path -Parent $LogFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $LogFile -Value ($obj | ConvertTo-Json -Depth 10 -Compress) -Encoding utf8
}
function Read-Records {
    if (-not (Test-Path $LogFile)) { return @() }
    return @(Get-Content $LogFile -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { try { $_ | ConvertFrom-Json } catch { } })
}

$root = Find-ProjectRoot
$projectName = Split-Path -Leaf $root

switch ($Action) {
    'add' {
        if (-not (Get-TrackingSettings -ProjectRoot $root).feedbackLog) { Write-Host "FEEDBACK_LOG_OFF: nothing recorded."; exit 0 }
        if (-not $Type) { throw "-Type is required (correction, rule-break, stuck, good)." }
        $rec = [ordered]@{ ts = (Get-Date).ToString('o'); kind = 'event'; version = Get-PluginVersion; project = $projectName
                           ticket = if ($Ticket) { $Ticket.ToUpper() } else { '' }; skill = $Skill; type = $Type; note = Hide-Secrets $Note }
        Write-Record $rec
        Write-Host "LOGGED $($rec.type) [$($rec.skill)] $($rec.ticket)"
    }
    'ticket-summary' {
        if (-not $Ticket) { throw "-Ticket is required." }
        $Ticket = $Ticket.ToUpper()
        if (-not $TicketsDir) {
            $TicketsDir = Get-TicketsDir -ProjectRoot $root
        }
        $stateFile = Join-Path (Join-Path $TicketsDir $Ticket) 'state.json'
        $timingFile = Join-Path (Join-Path $TicketsDir $Ticket) 'timing.json'
        $stages = [ordered]@{}; $measured = $true
        if (Test-Path $timingFile) {
            foreach ($h in @((Get-Content $timingFile -Raw | ConvertFrom-Json).entries)) {
                if (-not $h) { continue }
                if (-not $stages.Contains($h.stage)) { $stages[$h.stage] = [ordered]@{ runs = 0; minutes = 0.0; activeMinutes = 0.0; userTurns = 0; measured = $true } }
                $s = $stages[$h.stage]; $s.runs++
                $s.minutes = [math]::Round($s.minutes + [double]$h.wallMinutes, 1)
                $s.activeMinutes = [math]::Round($s.activeMinutes + [double]$h.activeMinutes, 1)
                $s.userTurns += [int]$h.userTurns
            }
        }
        elseif (Test-Path $stateFile) {
            $state = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($h in @($state.history)) {
                if (-not $h) { continue }
                if (-not $stages.Contains($h.stage)) { $stages[$h.stage] = [ordered]@{ runs = 0; minutes = 0.0; userTurns = 0; measured = $true } }
                $s = $stages[$h.stage]; $s.runs++
                if ($h.source -eq 'timer') { $s.minutes = [math]::Round($s.minutes + [double]$h.minutes, 1); $s.userTurns += [int]$h.userTurns }
                else { $s.measured = $false; $measured = $false }
            }
        }
        $events = @(Read-Records | Where-Object { $_.kind -eq 'event' -and $_.ticket -eq $Ticket })
        $counts = [ordered]@{}
        foreach ($t in 'correction','rule-break','stuck','good') { $counts[$t] = @($events | Where-Object type -eq $t).Count }
        $total = 0.0; foreach ($k in $stages.Keys) { $total += $stages[$k].minutes }
        $rec = [ordered]@{ ts = (Get-Date).ToString('o'); kind = 'ticket-summary'; version = Get-PluginVersion; project = $projectName
                           ticket = $Ticket; stages = $stages; totalMinutes = [math]::Round($total, 1); fullyMeasured = $measured
                           events = $counts; skipped = Hide-Secrets $Skipped }
        Write-Record $rec
        Write-Host "TICKET SUMMARY $Ticket (plugin $($rec.version), $projectName)"
        foreach ($k in $stages.Keys) { $s = $stages[$k]; Write-Host ('  {0,-14} runs {1}  {2,6} min  userTurns {3}{4}' -f $k, $s.runs, $s.minutes, $s.userTurns, $(if ($s.measured) { '' } else { '  (not measured)' })) }
        Write-Host ("  total {0} min · corrections {1} · rule-breaks {2} · stuck {3} · good {4}" -f $rec.totalMinutes, $counts['correction'], $counts['rule-break'], $counts['stuck'], $counts['good'])
        if ($Skipped) { Write-Host "  skipped: $($rec.skipped)" }
    }
    'summary' {
        $all = Read-Records
        if ($Since) { $d = [datetime]::Parse($Since); $all = @($all | Where-Object { ([datetime]$_.ts) -ge $d }) }
        if ($Project) { $all = @($all | Where-Object project -eq $Project) }
        $events = @($all | Where-Object kind -eq 'event')
        $sums = @($all | Where-Object kind -eq 'ticket-summary')
        Write-Host ("PLUGIN LOG {0} · {1} events · {2} tickets summarised · versions: {3}" -f $LogFile, $events.Count, $sums.Count, ((@($all.version) | Sort-Object -Unique) -join ', '))
        Write-Host ''
        Write-Host ('{0,-15} {1,10} {2,10} {3,6} {4,5}' -f 'Skill', 'correction', 'rule-break', 'stuck', 'good')
        foreach ($g in ($events | Group-Object skill | Sort-Object Count -Descending)) {
            $c = { param($t) @($g.Group | Where-Object type -eq $t).Count }
            Write-Host ('{0,-15} {1,10} {2,10} {3,6} {4,5}' -f $g.Name, (& $c 'correction'), (& $c 'rule-break'), (& $c 'stuck'), (& $c 'good'))
        }
        if ($sums.Count) {
            Write-Host ''
            Write-Host 'Average measured minutes per stage (fully timed runs only):'
            $byStage = @{}
            foreach ($s in $sums) { foreach ($p in $s.stages.PSObject.Properties) { if ($p.Value.measured) { if (-not $byStage[$p.Name]) { $byStage[$p.Name] = @() }; $byStage[$p.Name] += [double]$p.Value.minutes } } }
            foreach ($k in ($byStage.Keys | Sort-Object)) { $v = $byStage[$k]; Write-Host ('  {0,-14} {1,6:N1} min  (n={2})' -f $k, (($v | Measure-Object -Average).Average), $v.Count) }
        }
        $recent = @($events | Where-Object { $_.type -in 'correction','rule-break','stuck' } | Select-Object -Last 15)
        if ($recent.Count) {
            Write-Host ''; Write-Host 'Latest problems:'
            foreach ($e in $recent) { Write-Host ('  {0:yyyy-MM-dd} {1,-10} [{2}] {3}: {4}' -f ([datetime]$e.ts), $e.type, $e.skill, $e.ticket, $e.note) }
        }
    }
}
