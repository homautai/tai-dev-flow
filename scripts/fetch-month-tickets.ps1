<#
.SYNOPSIS
    List the Jira tickets a user worked on in a period, for every ticket source in timekeeper.json.
.DESCRIPTION
    For each source whose [from, to] overlaps the period, runs the source's JQL (with {start}/{end}
    filled in) against its Jira site via REST, and writes one JSON file with all tickets.
    "currentUser()" in the JQL is the account that owns the API token.
    Use this when no Jira MCP tool can reach the site.
.EXAMPLE
    pwsh -File fetch-month-tickets.ps1 -Period 2026-09 -OutFile ~/.dev-flow/timekeeper/2026-09/tickets.json
#>
param(
    [string]$Period,             # yyyy-MM
    [string]$Start,              # yyyy-MM-dd (alternative to -Period)
    [string]$End,                # yyyy-MM-dd
    [string]$ConfigFile = (Join-Path $HOME '.dev-flow/timekeeper.json'),
    [Parameter(Mandatory=$true)][string]$OutFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
Set-StrictMode -Off

if ($Period) {
    $first = [datetime]::ParseExact("$Period-01", 'yyyy-MM-dd', $null)
    $Start = $first.ToString('yyyy-MM-dd'); $End = $first.AddMonths(1).AddDays(-1).ToString('yyyy-MM-dd')
}
if (-not $Start -or -not $End) { throw "Pass -Period yyyy-MM or -Start/-End yyyy-MM-dd." }
if (-not (Test-Path $ConfigFile)) { throw "Config not found: $ConfigFile (copy templates/timekeeper.template.json)." }
$config = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json

$fields = @('summary','issuetype','status','created','updated','resolutiondate','parent','assignee')
$all = New-Object System.Collections.Generic.List[object]
$report = New-Object System.Collections.Generic.List[object]

foreach ($src in $config.sources) {
    $sFrom = if ($src.from) { $src.from } else { '0001-01-01' }
    $sTo = if ($src.to) { $src.to } else { '9999-12-31' }
    $effStart = @($Start, $sFrom) | Sort-Object | Select-Object -Last 1
    $effEnd = @($End, $sTo) | Sort-Object | Select-Object -First 1
    if ($effStart -gt $effEnd) { continue }

    $site = ([string]$src.jiraSite).TrimEnd('/')
    $siteHost = ([uri]$site).Host
    $creds = Get-AtlassianCredentials -SiteHost $siteHost
    if (-not $creds.Email -or -not $creds.JiraToken) {
        $report.Add([pscustomobject]@{ source = $src.name; status = 'NO_CREDENTIALS'; count = 0 }); continue
    }
    $headers = New-BasicAuthHeaders -User $creds.Email -Secret $creds.JiraToken -Extra @{ 'Content-Type' = 'application/json' }
    $jql = ([string]$src.jql).Replace('{start}', $effStart).Replace('{end}', $effEnd)

    $token = $null; $count = 0; $status = 'OK'
    do {
        $body = @{ jql = $jql; fields = $fields; maxResults = 100 }
        if ($token) { $body.nextPageToken = $token }
        try {
            $resp = Invoke-RestMethod -Uri "$site/rest/api/3/search/jql" -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 5)
        } catch {
            $code = $null; if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            $status = "HTTP_$code"; break
        }
        foreach ($i in $resp.issues) {
            $f = $i.fields
            $all.Add([pscustomobject]@{
                key = $i.key
                summary = $f.summary
                source = $src.name
                issueType = $f.issuetype.name
                isSubtask = [bool]$f.issuetype.subtask
                status = $f.status.name
                created = $f.created
                updated = $f.updated
                resolved = $f.resolutiondate
                parentKey = if ($f.parent) { $f.parent.key } else { $null }
                parentType = if ($f.parent) { $f.parent.fields.issuetype.name } else { $null }
                assignee = if ($f.assignee) { $f.assignee.displayName } else { $null }
                link = "$site/browse/$($i.key)"
            })
            $count++
        }
        $token = $resp.nextPageToken
    } while ($token -and -not $resp.isLast)
    $report.Add([pscustomobject]@{ source = $src.name; status = $status; count = $count; start = $effStart; end = $effEnd })
}

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[pscustomobject]@{ period = @{ start = $Start; end = $End }; sources = $report; tickets = $all } |
    ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding utf8
$report | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Tickets: $($all.Count) -> $OutFile"
