#Requires -Version 7
<#
.SYNOPSIS
    Call an API from config_swagger.json without ever printing the bearer token.
.DESCRIPTION
    Prints one status line followed by the response body, so the result can be pasted into the
    API test log. Use -Expect to make the exit code reflect pass/fail.
.EXAMPLE
    pwsh -File call-api.ps1 -Target dev -Method GET -Path /orders/42 -Expect 200
.EXAMPLE
    pwsh -File call-api.ps1 -Target local -Method POST -Path /orders -BodyFile body.json -Expect 201
#>
param(
    [Parameter(Mandatory=$true)][string]$Target,
    [ValidateSet('GET','POST','PUT','PATCH','DELETE')][string]$Method = 'GET',
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$Body,
    [string]$BodyFile,
    [string]$ConfigFile,
    [string[]]$Header = @(),      # extra headers as "Name: value", e.g. -Header "X-Tenant: ACME"
    [int]$Expect,
    [int]$MaxChars = 20000,
    [string]$OutFile,
    [switch]$NoAuth
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/ApiConfig.ps1')
Set-StrictMode -Off

if (-not $ConfigFile) {
    $root = Find-ProjectRoot
    $pc = Get-ProjectConfig -ProjectRoot $root
    $rel = Get-OptionalProperty (Get-OptionalProperty $pc 'apiTest') 'configFile'
    if (-not $rel) { $rel = 'docs/API_test/config_swagger.json' }
    $ConfigFile = Join-Path $root $rel
}

$config = Read-ApiConfig $ConfigFile
$api = Resolve-ApiTarget -Config $config -Target $Target

$uri = if ($Path -match '^https?://') { $Path } else { $api.BaseUrl + '/' + $Path.TrimStart('/') }
$headers = @{ Accept = 'application/json' }
foreach ($h in $Header) { $i = $h.IndexOf(':'); if ($i -gt 0) { $headers[$h.Substring(0, $i).Trim()] = $h.Substring($i + 1).Trim() } }
if (-not $NoAuth) {
    if (-not $api.Token) {
        Write-Host "NO_TOKEN: no bearer token for target '$Target'. Log in through the browser and save it with save-token.ps1 -Target $Target (field $($api.TokenField))." -ForegroundColor Yellow
        exit 3
    }
    $exp = Get-JwtExpiry $api.Token
    if ($exp -and $exp -lt [DateTime]::UtcNow.AddSeconds(30)) {
        Write-Host "TOKEN_EXPIRED: token for '$Target' expired at $($exp.ToLocalTime().ToString('yyyy-MM-dd HH:mm')). Log in again (see api-test skill, Token)." -ForegroundColor Yellow
        exit 4
    }
    $headers['Authorization'] = "Bearer $($api.Token)"
}

$params = @{ Uri = $uri; Method = $Method; Headers = $headers; SkipHttpErrorCheck = $true }
if ($uri -match '^https://(localhost|127\.0\.0\.1)') { $params['SkipCertificateCheck'] = $true }
if ($BodyFile) { $Body = Get-Content $BodyFile -Raw -Encoding UTF8 }
if ($Body) { $params['Body'] = [System.Text.Encoding]::UTF8.GetBytes($Body); $params['ContentType'] = 'application/json; charset=utf-8' }

$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $resp = Invoke-WebRequest @params
} catch {
    $sw.Stop()
    Write-Host "NETWORK_ERROR $Method $uri ($($sw.ElapsedMilliseconds) ms): $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
$sw.Stop()

$status = [int]$resp.StatusCode
$content = [string]$resp.Content
if ($OutFile) { Set-Content -Path $OutFile -Value $content -Encoding utf8 }

$mark = ''
if ($Expect) { $mark = if ($status -eq $Expect) { ' PASS' } else { " FAIL (expected $Expect)" } }
Write-Host "HTTP $status $Method $uri ($($sw.ElapsedMilliseconds) ms)$mark"

$pretty = $content
try { if ($content) { $pretty = $content | ConvertFrom-Json -Depth 50 | ConvertTo-Json -Depth 50 } } catch { }
if ($api.Token) { $pretty = $pretty.Replace($api.Token, '<TOKEN>') }
if ($pretty.Length -gt $MaxChars) { $pretty = $pretty.Substring(0, $MaxChars) + "`n... (truncated, $($content.Length) chars total; use -OutFile for the full body)" }
Write-Output $pretty

if ($Expect -and $status -ne $Expect) { exit 1 }
exit 0
