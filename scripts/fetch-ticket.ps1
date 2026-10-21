<#
.SYNOPSIS
    Fetch a Jira ticket and save it as Markdown.
.EXAMPLE
    pwsh -File fetch-ticket.ps1 PROJ-123        # writes <tickets dir>/PROJ-123/ticket.md
.NOTES
    Credentials: see lib/Common.ps1 (env vars, ~/.dev-flow/credentials.json, or legacy .jira/config.json).
    Jira URL:    jira.baseUrl in the project's .dev-flow.json, or -JiraBaseUrl.
#>
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$TicketId,

    # Folder that receives ticket.md. Default: <tickets dir>/<KEY> from .dev-flow.json (workspace aware).
    [string]$OutDir,

    [string]$JiraBaseUrl,
    [string]$ProjectRoot,
    [string]$CacheDir
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Adf.ps1')
Set-StrictMode -Off   # the ADF converter probes optional properties

if (-not $ProjectRoot) { $ProjectRoot = Find-ProjectRoot }
$projectConfig = Get-ProjectConfig -ProjectRoot $ProjectRoot
$SiteUrl = Get-JiraBaseUrl -Override $JiraBaseUrl -ProjectConfig $projectConfig
$CacheDir = Get-CacheDir -ProjectRoot $ProjectRoot -Override $CacheDir

$creds = Get-AtlassianCredentials -ProjectRoot $ProjectRoot
if (-not $creds.Email -or -not $creds.JiraToken) {
    Write-Warning "Jira email or API token is not set. Fill ~/.dev-flow/credentials.json (template: templates/credentials.template.json) or set DEVFLOW_ATLASSIAN_EMAIL / DEVFLOW_JIRA_API_TOKEN."
    exit 1
}

$TicketId = $TicketId.Trim().ToUpper()
Write-Host "Fetching Jira Ticket $TicketId..." -ForegroundColor Cyan

$Url = "$SiteUrl/rest/api/3/issue/$TicketId"
$headers = New-BasicAuthHeaders -User $creds.Email -Secret $creds.JiraToken

try {
    $rawResponse = Invoke-WebRequest -Uri $Url -Headers $headers -Method Get -UseBasicParsing
    $jsonContent = $rawResponse.Content
} catch {
    $statusCode = $null
    if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
    Write-Error "Failed to fetch ticket $TicketId. HTTP Status Code: $statusCode. Error: $($_.Exception.Message)"
    exit 1
}

# Save raw response to cache (never committed: .dev-flow/cache is git-ignored)
$CacheJsonFile = Join-Path $CacheDir "$TicketId.json"
Set-Content -Path $CacheJsonFile -Value $jsonContent -Encoding UTF8

# Parse the JSON
$issue = $jsonContent | ConvertFrom-Json
$fields = $issue.fields

# Build fields variables
$summary = $fields.summary
$status = if ($fields.status) { $fields.status.name } else { "N/A" }
$priority = if ($fields.priority) { $fields.priority.name } else { "N/A" }
$assignee = if ($fields.assignee) { $fields.assignee.displayName } else { "Unassigned" }
$reporter = if ($fields.reporter) { $fields.reporter.displayName } else { "N/A" }
$created = if ($fields.created) { $fields.created } else { "N/A" }

# Extract & format description
$descriptionMd = ""
if ($fields.description) {
    $descriptionMd = Convert-AdfToMarkdown $fields.description
} else {
    $descriptionMd = "*No description provided.*"
}

# Format Subtasks
$subtasksMd = ""
if ($fields.subtasks -and $fields.subtasks.Count -gt 0) {
    $subtasksMd = "### Sub-tasks`n`n"
    foreach ($subtask in $fields.subtasks) {
        $stKey = $subtask.key
        $stSummary = $subtask.fields.summary
        $stStatus = $subtask.fields.status.name
        $subtasksMd += "- **$stKey**: $stSummary [$stStatus]`n"
    }
}

# Format Issue Links
$linksMd = ""
if ($fields.issuelinks -and $fields.issuelinks.Count -gt 0) {
    $linksMd = "### Linked Issues`n`n"
    foreach ($link in $fields.issuelinks) {
        $linkTypeName = $link.type.name
        if ($null -ne $link.outwardIssue) {
            $linkedKey = $link.outwardIssue.key
            $linkedSummary = $link.outwardIssue.fields.summary
            $linkedStatus = $link.outwardIssue.fields.status.name
            $linkRelation = $link.type.outward
            $linksMd += "- $linkRelation **$linkedKey**: $linkedSummary [$linkedStatus] ($linkTypeName)`n"
        } elseif ($null -ne $link.inwardIssue) {
            $linkedKey = $link.inwardIssue.key
            $linkedSummary = $link.inwardIssue.fields.summary
            $linkedStatus = $link.inwardIssue.fields.status.name
            $linkRelation = $link.type.inward
            $linksMd += "- $linkRelation **$linkedKey**: $linkedSummary [$linkedStatus] ($linkTypeName)`n"
        }
    }
}

# Format Comments
$commentsMd = ""
if ($fields.comment -and $fields.comment.comments -and $fields.comment.comments.Count -gt 0) {
    $commentsMd = "### Comments`n`n"
    foreach ($comment in $fields.comment.comments) {
        $author = $comment.author.displayName
        $cCreated = $comment.created
        $cBody = Convert-AdfToMarkdown $comment.body
        $commentsMd += "#### Comment by $author on $cCreated`n$cBody`n`n"
    }
}

# Build Markdown representation
$markdownOutput = @"
# [$TicketId] $summary

- **Status**: $status
- **Priority**: $priority
- **Assignee**: $assignee
- **Reporter**: $reporter
- **Created**: $created
- **Jira Link**: $SiteUrl/browse/$TicketId

## Description

$descriptionMd

$subtasksMd
$linksMd
$commentsMd
"@

# Save formatted Markdown
if (-not $OutDir) { $OutDir = Join-Path (Get-TicketsDir -ProjectRoot $ProjectRoot) $TicketId }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$MdFile = Join-Path $OutDir "ticket.md"
if ($OutDir -eq $CacheDir) { $MdFile = Join-Path $OutDir "$TicketId.md" }
Set-Content -Path $MdFile -Value $markdownOutput -Encoding UTF8

Write-Host $markdownOutput
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray
Write-Host "Raw JSON: $CacheJsonFile" -ForegroundColor DarkGray
Write-Host "Markdown: $MdFile" -ForegroundColor DarkGray
