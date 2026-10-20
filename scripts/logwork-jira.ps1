<#
.SYNOPSIS
    Log work on a Jira ticket.
.EXAMPLE
    pwsh -File logwork-jira.ps1 WEC-123 "2h 30m" "Implement + API test on dev"
#>
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$TicketId,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$TimeSpent,

    [Parameter(Mandatory=$false, Position=2)]
    [string]$Comment = "Worked on ticket",

    [Parameter(Mandatory=$false, Position=3)]
    [string]$Started,

    [string]$JiraBaseUrl,
    [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
Set-StrictMode -Off

if (-not $ProjectRoot) { $ProjectRoot = Find-ProjectRoot }
$projectConfig = Get-ProjectConfig -ProjectRoot $ProjectRoot
$SiteUrl = Get-JiraBaseUrl -Override $JiraBaseUrl -ProjectConfig $projectConfig

$creds = Get-AtlassianCredentials -ProjectRoot $ProjectRoot
if (-not $creds.Email -or -not $creds.JiraToken) {
    Write-Warning "Jira email or API token is not set. Fill ~/.dev-flow/credentials.json or set DEVFLOW_ATLASSIAN_EMAIL / DEVFLOW_JIRA_API_TOKEN."
    exit 1
}

$TicketId = $TicketId.Trim().ToUpper()
Write-Host "Logging work for Jira Ticket $TicketId..." -ForegroundColor Cyan

# Default Started date if not provided
if ([string]::IsNullOrEmpty($Started)) {
    $now = Get-Date
    $tz = $now.ToString("zzz").Replace(":", "")
    $Started = $now.ToString("yyyy-MM-ddTHH:mm:ss.000") + $tz
}

# Build the REST endpoint URL
$BaseUrl = "$SiteUrl/rest/api/3"
$Url = "$BaseUrl/issue/$TicketId/worklog"

# Setup Authorization headers
$pair = "$($creds.Email):$($creds.JiraToken)"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)
$headers = @{
    Authorization = "Basic $base64"
    Accept = "application/json"
    "Content-Type" = "application/json"
}

# Build the request body
$commentObj = @{
    type = "doc"
    version = 1
    content = @(
        @{
            type = "paragraph"
            content = @(
                @{
                    type = "text"
                    text = $Comment
                }
            )
        }
    )
}

$bodyObj = @{
    timeSpent = $TimeSpent
    started = $Started
    comment = $commentObj
}

$body = $bodyObj | ConvertTo-Json -Depth 5

# Make the POST request
try {
    $response = Invoke-RestMethod -Uri $Url -Headers $headers -Method Post -Body $body
    Write-Host "Successfully logged $TimeSpent on ticket $TicketId!" -ForegroundColor Green
    Write-Host "Worklog ID: $($response.id)" -ForegroundColor DarkGray
    Write-Host "Started: $Started" -ForegroundColor DarkGray
} catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__
    Write-Error "Failed to log work for ticket $TicketId. HTTP Status Code: $statusCode. Error: $_"
    exit 1
}
