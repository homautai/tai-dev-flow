<#
.SYNOPSIS
    Fetch a Bitbucket pull request (metadata, diff, comments) and save it as Markdown.
.EXAMPLE
    pwsh -File fetch-pr.ps1 my-api 123
.NOTES
    Workspace: -Workspace, or bitbucket.workspace in the project's .dev-flow.json.
    Token:     bitbucketApiToken (see lib/Common.ps1).
#>
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$RepoName,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$PrId,

    [Parameter(Mandatory=$false, Position=2)]
    [string]$Workspace,

    [string]$ProjectRoot,
    [string]$CacheDir
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
Set-StrictMode -Off

if (-not $ProjectRoot) { $ProjectRoot = Find-ProjectRoot }
$projectConfig = Get-ProjectConfig -ProjectRoot $ProjectRoot
if (-not $Workspace) {
    $Workspace = Get-OptionalProperty (Get-OptionalProperty $projectConfig 'bitbucket') 'workspace'
}
if (-not $Workspace) {
    Write-Error "Bitbucket workspace not set. Pass -Workspace or set bitbucket.workspace in .dev-flow.json."
    exit 1
}
$CacheDir = Get-CacheDir -ProjectRoot $ProjectRoot -Override $CacheDir

$creds = Get-AtlassianCredentials -ProjectRoot $ProjectRoot
if (-not $creds.Email -or -not $creds.BitbucketToken) {
    Write-Warning "Bitbucket token is not set. Fill atlassian.bitbucketApiToken in ~/.dev-flow/credentials.json or set DEVFLOW_BITBUCKET_API_TOKEN."
    exit 1
}

$RepoNameClean = $RepoName.Trim()
$PrIdClean = $PrId.Trim()
Write-Host "Fetching PR #$PrIdClean from repo $Workspace/$RepoNameClean..." -ForegroundColor Cyan

# Bitbucket API Endpoints
# Note: Bitbucket slugs are case-insensitive, but usually lowercase. Let's try lowercase slug.
$RepoSlug = $RepoNameClean.ToLower()
$BaseUrl = "https://api.bitbucket.org/2.0/repositories/$Workspace/$RepoSlug"
$PrUrl = "$BaseUrl/pullrequests/$PrIdClean"
$DiffUrl = "$BaseUrl/pullrequests/$PrIdClean/diff"

# Setup Authorization Headers
# Atlassian API tokens (ATATT...) are used in Basic Auth with the account email as the username
$pair = "$($creds.Email):$($creds.BitbucketToken)"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)

$headers = @{
    Authorization = "Basic $base64"
    Accept = "application/json"
}

# Function to attempt API calls (first Basic Auth, fallback to Bearer)
function Invoke-BitbucketApi($uri, $headers, $outFile = $null) {
    try {
        if ($outFile) {
            Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -OutFile $outFile -UseBasicParsing
            return $null
        } else {
            return Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -UseBasicParsing
        }
    } catch {
        # Fallback to Bearer token if Basic Auth fails with 401/403
        $statusCode = $_.Exception.Response.StatusCode.Value__
        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            Write-Host "Basic Auth failed with status code $statusCode. Trying Bearer Token Auth..." -ForegroundColor Yellow
            $bearerHeaders = @{
                Authorization = "Bearer $($creds.BitbucketToken)"
                Accept = "application/json"
            }
            if ($outFile) {
                Invoke-WebRequest -Uri $uri -Headers $bearerHeaders -Method Get -OutFile $outFile -UseBasicParsing
                return $null
            } else {
                return Invoke-WebRequest -Uri $uri -Headers $bearerHeaders -Method Get -UseBasicParsing
            }
        } else {
            throw $_
        }
    }
}

# 1. Fetch Pull Request Metadata
try {
    $prResponse = Invoke-BitbucketApi -uri $PrUrl -headers $headers
    $prJson = $prResponse.Content
} catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__
    Write-Error "Failed to fetch Pull Request details. HTTP Status Code: $statusCode. Error: $_"
    exit 1
}

# Save raw PR metadata to cache
$CacheJsonFile = Join-Path $CacheDir "PR-$RepoNameClean-$PrIdClean.json"
Set-Content -Path $CacheJsonFile -Value $prJson -Encoding UTF8
$prObj = $prJson | ConvertFrom-Json

# 2. Fetch Pull Request Diff
$DiffUrl = $prObj.links.diff.href
$CacheDiffFile = Join-Path $CacheDir "PR-$RepoNameClean-$PrIdClean.diff"
try {
    Write-Host "Downloading PR Diff from $DiffUrl..." -ForegroundColor Cyan
    Invoke-BitbucketApi -uri $DiffUrl -headers $headers -outFile $CacheDiffFile
} catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__
    Write-Warning "Failed to fetch PR Diff (HTTP $statusCode). Continuing with metadata only."
}

# 3. Fetch Pull Request Comments
$CommentsUrl = $prObj.links.comments.href
$CacheCommentsFile = Join-Path $CacheDir "PR-$RepoNameClean-$PrIdClean-comments.json"
$commentsMd = ""
try {
    Write-Host "Downloading PR Comments from $CommentsUrl..." -ForegroundColor Cyan
    $commentsResponse = Invoke-BitbucketApi -uri $CommentsUrl -headers $headers
    $commentsJson = $commentsResponse.Content
    Set-Content -Path $CacheCommentsFile -Value $commentsJson -Encoding UTF8
    
    $commentsObj = $commentsJson | ConvertFrom-Json
    if ($commentsObj.values -and $commentsObj.values.Count -gt 0) {
        $commentsMd = "`n`n## Comments`n"
        foreach ($c in $commentsObj.values) {
            if ($null -eq $c.content -or $null -eq $c.content.raw) { continue }
            $cAuthor = $c.user.display_name
            $cCreated = $c.created_on
            $cBody = $c.content.raw
            $commentsMd += "`n### Comment by $cAuthor on $cCreated`n$cBody`n"
        }
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__
    Write-Warning "Failed to fetch PR Comments (HTTP $statusCode). Continuing without comments."
}

# 4. Format output Markdown
$title = $prObj.title
$description = if ($prObj.description) { $prObj.description } else { "*No description provided.*" }
$status = $prObj.state
$author = $prObj.author.display_name
$sourceBranch = $prObj.source.branch.name
$targetBranch = $prObj.destination.branch.name
$created = $prObj.created_on
$bitbucketLink = $prObj.links.html.href

$diffSummary = "*Diff download failed.*"
if (Test-Path $CacheDiffFile) {
    $diffLines = Get-Content $CacheDiffFile
    if ($diffLines.Count -eq 0) {
        $diffSummary = "*No code changes found or diff is empty.*"
    } else {
        $diffSummary = "Diff downloaded successfully ($($diffLines.Count) lines of changes)."
    }
}

$markdownOutput = @"
# [PR #$PrIdClean] $title

- **Repository**: $Workspace/$RepoNameClean
- **Status**: $status
- **Author**: $author
- **Source**: $sourceBranch
- **Target**: $targetBranch
- **Created**: $created
- **Link**: $bitbucketLink

## Description

$description

## Code Changes Summary

$diffSummary
$commentsMd
"@

# Save formatted Markdown to cache
$CacheMdFile = Join-Path $CacheDir "PR-$RepoNameClean-$PrIdClean.md"
Set-Content -Path $CacheMdFile -Value $markdownOutput -Encoding UTF8

# Print Summary to console
Write-Host "`n================================================================================" -ForegroundColor Gray
Write-Host "PULL REQUEST SUMMARY" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Gray
Write-Host $markdownOutput
Write-Host "================================================================================" -ForegroundColor Gray
Write-Host "Metadata JSON saved to: $CacheJsonFile" -ForegroundColor DarkGray
Write-Host "Diff patch saved to: $CacheDiffFile" -ForegroundColor DarkGray
Write-Host "Markdown summary saved to: $CacheMdFile" -ForegroundColor DarkGray
