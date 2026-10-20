#Requires -Version 7
<#
.SYNOPSIS
    Build a Timekeeper plan: every working day filled to exactly workday.hours.
.DESCRIPTION
    Input (-InputFile, JSON):
      { "period":   { "start": "2026-09-01", "end": "2026-09-30" },
        "holidays": [ { "date": "2026-09-02", "name": "National Day", "worked": false } ],
        "leaves":   [ { "date": "2026-09-15", "hours": 8, "type": "Annual Leave" } ],
        "skipDates":[ "2026-09-01" ],                       // days already logged in Timekeeper
        "tickets":  [ { "key": "WEC-1", "summary": "...", "source": "WeCRM", "issueType": "Sub-task",
                        "parentType": "Bug", "link": "https://...", "activeFrom": "2026-09-03",
                        "activeTo": "2026-09-12", "activityTypeId": null } ] }

    Per working day (config workday.days, minus holidays):
      holiday            -> Public Holiday, full day
      leave              -> Paid Leave (full or partial)
      meetings           -> from each source active that day (every workday / first workday of week)
      the rest           -> split EVENLY across tickets active that day, in workday.unit steps
                            (ties go to the ticket with fewer hours so far, then the older one).
      no active ticket   -> the most recently started ticket continues (or the next one to start).

    Output: <OutDir>/plan.json (neutral entries), plan.csv, timekeeper-entries.json (Timekeeper field
    names, chunked for posting), summary.json. Fails if any day does not sum to workday.hours.
#>
param(
    [Parameter(Mandatory=$true)][string]$InputFile,
    [string]$ConfigFile = (Join-Path $HOME '.dev-flow/timekeeper.json'),
    [Parameter(Mandatory=$true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off
$inv = [System.Globalization.CultureInfo]::InvariantCulture

$cfg = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
$in = Get-Content $InputFile -Raw -Encoding UTF8 | ConvertFrom-Json

$dayHours = [double]$cfg.workday.hours
$unit = [double]$cfg.workday.unit
$workdayNames = @($cfg.workday.days)
$dateFormat = $cfg.timekeeper.dateFormat
function D([string]$s) { [datetime]::ParseExact($s.Substring(0,10), 'yyyy-MM-dd', $inv) }
function S([datetime]$d) { $d.ToString('yyyy-MM-dd', $inv) }

$start = D $in.period.start; $end = D $in.period.end
$holidays = @{}; foreach ($h in @($in.holidays)) { if ($h) { $holidays[$h.date] = $h } }
$leaves = @{}; foreach ($l in @($in.leaves)) { if ($l) { $leaves[$l.date] = [double]$leaves[$l.date] + [double]$l.hours } }
$skip = @{}; foreach ($s in @($in.skipDates)) { if ($s) { $skip[$s] = $true } }
$sources = @{}; foreach ($src in $cfg.sources) { $sources[$src.name] = $src }

function Is-Workday([datetime]$d) { $workdayNames -contains $d.ToString('ddd', $inv) }
function Is-Free([datetime]$d) {   # a workday on which normal work happens (no holiday, not full leave)
    if (-not (Is-Workday $d)) { return $false }
    $k = S $d
    if ($holidays.ContainsKey($k) -and -not $holidays[$k].worked) { return $false }
    if ([double]$leaves[$k] -ge $dayHours) { return $false }
    return $true
}
function Source-Active($src, [datetime]$d) {
    $f = if ($src.from) { D $src.from } else { [datetime]::MinValue }
    $t = if ($src.to) { D $src.to } else { [datetime]::MaxValue }
    return ($d -ge $f -and $d -le $t)
}
function First-FreeDayOfWeek([datetime]$d, $src) {
    $monday = $d.AddDays(-(([int]$d.DayOfWeek + 6) % 7))
    for ($i = 0; $i -lt 7; $i++) {
        $x = $monday.AddDays($i)
        if ($x -ge $start -and $x -le $end -and (Is-Free $x) -and (Source-Active $src $x) -and -not $skip.ContainsKey((S $x))) { return $x }
    }
    return $null
}
function Activity-Id($t) {
    if ($t.activityTypeId) { return [int]$t.activityTypeId }
    $rule = [string]$sources[$t.source].activityRule
    if ($rule -match '^\d+$') { return [int]$rule }
    if ($t.issueType -eq 'Bug' -or $t.parentType -eq 'Bug') { return [int]$cfg.codes.activityTypes.bug }
    return [int]$cfg.codes.activityTypes.task
}

# Tickets: normalise windows so each one covers at least one free workday
$tickets = @()
foreach ($t in @($in.tickets)) {
    if (-not $t) { continue }
    if (-not $sources.ContainsKey($t.source)) { throw "Ticket $($t.key): unknown source '$($t.source)'." }
    $from = D $t.activeFrom; $to = if ($t.activeTo) { D $t.activeTo } else { $end }
    if ($from -lt $start) { $from = $start }; if ($to -gt $end) { $to = $end }
    if ($to -lt $from) { $to = $from }
    $hasFree = $false
    for ($x = $from; $x -le $to; $x = $x.AddDays(1)) { if (Is-Free $x) { $hasFree = $true; break } }
    if (-not $hasFree) {
        $x = $from; while ($x -le $end -and -not (Is-Free $x)) { $x = $x.AddDays(1) }
        if ($x -gt $end) { $x = $from; while ($x -ge $start -and -not (Is-Free $x)) { $x = $x.AddDays(-1) } }
        if ($x -ge $start -and $x -le $end) { $from = $x; $to = $x }
    }
    $tickets += [pscustomobject]@{ t = $t; from = $from; to = $to; units = 0 }
}

$entries = New-Object System.Collections.Generic.List[object]
function Add-Entry([datetime]$d, [double]$h, $cust, $rep, $act, [string]$desc, [string]$kind, [string]$key = '', [string]$link = '') {
    if ($h -le 0) { return }
    $entries.Add([pscustomobject]@{ date = (S $d); hours = $h; customerId = [int]$cust; reportingCodeId = [int]$rep;
        activityTypeId = [int]$act; description = $desc; ticketNumber = $key; ticketLink = $link; kind = $kind;
        isBillable = $false; isOvertime = $false })
}

$warnings = New-Object System.Collections.Generic.List[string]
for ($d = $start; $d -le $end; $d = $d.AddDays(1)) {
    if (-not (Is-Workday $d)) { continue }
    $k = S $d
    if ($skip.ContainsKey($k)) { continue }
    if ($holidays.ContainsKey($k) -and -not $holidays[$k].worked) {
        $c = $cfg.codes.publicHoliday
        Add-Entry $d $dayHours $c.customerId $c.reportingCodeId $c.activityTypeId $c.description 'holiday'; continue
    }
    $leave = [math]::Min([double]$leaves[$k], $dayHours)
    if ($leave -gt 0) {
        $c = $cfg.codes.paidLeave
        $desc = if ($leave -lt $dayHours) { $c.halfDayDescription } else { $c.description }
        Add-Entry $d $leave $c.customerId $c.reportingCodeId $c.activityTypeId $desc 'leave'
    }
    $remaining = $dayHours - $leave
    if ($remaining -le 0) { continue }

    foreach ($src in $cfg.sources) {
        if (-not (Source-Active $src $d)) { continue }
        foreach ($m in @($src.meetings)) {
            if (-not $m) { continue }
            if ($m.from -and $d -lt (D $m.from)) { continue }
            if ($m.to -and $d -gt (D $m.to)) { continue }
            $due = switch ($m.every) {
                'workday' { $true }
                'firstWorkdayOfWeek' { $f = First-FreeDayOfWeek $d $src; $f -and (S $f) -eq $k }
                default { $false }
            }
            if ($due -and $remaining -gt 0) {
                $h = [math]::Min([double]$m.hours, $remaining)
                Add-Entry $d $h $src.customerId $src.reportingCodeId $m.activityTypeId $m.description 'meeting'
                $remaining -= $h
            }
        }
    }
    if ($remaining -le 0) { continue }

    $active = @($tickets | Where-Object { $d -ge $_.from -and $d -le $_.to })
    if ($active.Count -eq 0) {
        $started = @($tickets | Where-Object { $_.from -le $d } | Sort-Object from -Descending)
        if ($started.Count -gt 0) { $active = @($started[0]) }
        else { $next = @($tickets | Sort-Object from); if ($next.Count -gt 0) { $active = @($next[0]) } }
        if ($active.Count -gt 0) { $warnings.Add("${k}: no ticket active, extended $($active[0].t.key)") }
    }
    if ($active.Count -eq 0) { throw "${k}: $remaining h left and there are no tickets at all." }

    $dayUnits = @{}; foreach ($a in $active) { $dayUnits[$a.t.key] = 0 }
    $n = [int][math]::Round($remaining / $unit)
    for ($i = 0; $i -lt $n; $i++) {
        $pick = $active | Sort-Object @{ e = { $dayUnits[$_.t.key] } }, @{ e = { $_.units } }, @{ e = { $_.from } }, @{ e = { $_.t.key } } | Select-Object -First 1
        $dayUnits[$pick.t.key]++; $pick.units++
    }
    foreach ($a in $active) {
        $h = $dayUnits[$a.t.key] * $unit
        if ($h -le 0) { continue }
        $src = $sources[$a.t.source]
        $desc = ([string]$src.descriptionFormat).Replace('{key}', $a.t.key).Replace('{summary}', $a.t.summary)
        Add-Entry $d $h $src.customerId $src.reportingCodeId (Activity-Id $a.t) $desc 'ticket' $a.t.key ([string]$a.t.link)
    }
}

# Validate: every processed workday sums to exactly dayHours
$byDay = $entries | Group-Object date
foreach ($g in $byDay) {
    $sum = ($g.Group | Measure-Object hours -Sum).Sum
    if ([math]::Abs($sum - $dayHours) -gt 0.001) { throw "Day $($g.Name) sums to $sum h, expected $dayHours h." }
}
$expectedDays = 0
for ($d = $start; $d -le $end; $d = $d.AddDays(1)) { if ((Is-Workday $d) -and -not $skip.ContainsKey((S $d))) { $expectedDays++ } }
if ($byDay.Count -ne $expectedDays) { throw "Planned $($byDay.Count) days, expected $expectedDays." }
foreach ($t in $tickets) { if ($t.units -eq 0) { $warnings.Add("$($t.t.key) got 0 h (too many tickets on its days)") } }

# Outputs
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$entries | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'plan.json') -Encoding utf8
$entries | Select-Object date, hours, kind, ticketNumber, description, activityTypeId, customerId, reportingCodeId |
    Export-Csv (Join-Path $OutDir 'plan.csv') -NoTypeInformation -Encoding utf8

$map = $cfg.timekeeper.entryFields
$idsAsStrings = [bool]$cfg.timekeeper.idsAsStrings
$tk = foreach ($e in $entries) {
    $o = [ordered]@{}
    foreach ($p in @('date','hours','customerId','reportingCodeId','activityTypeId','description','ticketNumber','ticketLink','isBillable','isOvertime')) {
        $names = @($map.$p) | Where-Object { $_ }
        if (-not $names) { continue }
        $v = $e.$p
        if ($p -eq 'date') { $v = (D $e.date).ToString($dateFormat, $inv) }
        if ($idsAsStrings -and $p -in @('customerId','reportingCodeId','activityTypeId')) { $v = [string]$v }
        foreach ($name in $names) { $o[$name] = $v }
    }
    if ($cfg.timekeeper.entryDefaults) {
        foreach ($d in $cfg.timekeeper.entryDefaults.PSObject.Properties) { if (-not $o.Contains($d.Name)) { $o[$d.Name] = $d.Value } }
    }
    [pscustomobject]$o
}
$tk = @($tk)
$tk | ConvertTo-Json -Depth 4 -AsArray | Set-Content (Join-Path $OutDir 'timekeeper-entries.json') -Encoding utf8
$size = [int]$cfg.timekeeper.postChunkSize; if ($size -le 0) { $size = 60 }
$chunkDir = Join-Path $OutDir 'chunks'; if (-not (Test-Path $chunkDir)) { New-Item -ItemType Directory -Path $chunkDir | Out-Null }
Get-ChildItem $chunkDir -Filter 'chunk-*.json' | Remove-Item
for ($i = 0; $i -lt $tk.Count; $i += $size) {
    $part = $tk[$i..([math]::Min($i + $size, $tk.Count) - 1)]
    $part | ConvertTo-Json -Depth 4 -AsArray -Compress | Set-Content (Join-Path $chunkDir ('chunk-{0:D2}.json' -f ($i / $size + 1))) -Encoding utf8
}

$summary = [ordered]@{
    period = "$($in.period.start)..$($in.period.end)"
    workdays = $expectedDays
    totalHours = ($entries | Measure-Object hours -Sum).Sum
    byKind = [ordered]@{}
    byTicket = [ordered]@{}
    entries = $entries.Count
    chunks = [int][math]::Ceiling($tk.Count / $size)
    warnings = $warnings
}
foreach ($g in ($entries | Group-Object kind)) { $summary.byKind[$g.Name] = ($g.Group | Measure-Object hours -Sum).Sum }
foreach ($g in ($entries | Where-Object kind -eq 'ticket' | Group-Object ticketNumber | Sort-Object Name)) { $summary.byTicket[$g.Name] = ($g.Group | Measure-Object hours -Sum).Sum }
$summary | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'summary.json') -Encoding utf8
$summary | ConvertTo-Json -Depth 4
