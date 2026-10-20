#Requires -Version 7
<#
.SYNOPSIS
    Try to obtain a bearer token for a target via OAuth2 and store it in the personal config.
.DESCRIPTION
    Uses tokenUrl / clientId / clientSecret (+ username/password for that target, if present) from
    config_swagger.json. Uses the password grant when a username is configured, otherwise
    client_credentials. Many SPA clients do not allow either grant: if this fails, log in through the
    browser (or a browser MCP) and paste the token into the config instead.
    The token is written to the config file and never printed.
.EXAMPLE
    pwsh -File get-token.ps1 -Target dev
#>
param(
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$ConfigFile,
    [ValidateSet('auto','password','client_credentials')][string]$GrantType = 'auto'
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
$auth = Get-ApiAuthSettings -Config $config -Target $Target
if (-not $auth -or -not $auth.TokenUrl -or -not $auth.ClientId) {
    Write-Host "NO_AUTH_CONFIG: tokenUrl/clientId missing for '$Target'. Log in manually and paste the token into the config." -ForegroundColor Yellow
    exit 3
}

if ($GrantType -eq 'auto') { $GrantType = if ($auth.Username) { 'password' } else { 'client_credentials' } }
$form = @{ grant_type = $GrantType; client_id = $auth.ClientId }
if ($auth.ClientSecret) { $form['client_secret'] = $auth.ClientSecret }
if ($auth.Scope) { $form['scope'] = $auth.Scope }
if ($GrantType -eq 'password') {
    if (-not $auth.Username -or -not $auth.Password) { Write-Host "NO_USER: username/password for '$Target' not configured." -ForegroundColor Yellow; exit 3 }
    $form['username'] = $auth.Username; $form['password'] = $auth.Password
}

$resp = Invoke-WebRequest -Uri $auth.TokenUrl -Method Post -Body $form -ContentType 'application/x-www-form-urlencoded' -SkipHttpErrorCheck
$status = [int]$resp.StatusCode
if ($status -ne 200) {
    $err = $resp.Content
    try { $j = $resp.Content | ConvertFrom-Json; $err = "$($j.error): $($j.error_description)" } catch { }
    Write-Host "TOKEN_FAILED HTTP $status ($GrantType): $err" -ForegroundColor Red
    Write-Host "Fallback: log in through the UI and capture the token (browser DevTools > Network > Authorization header), then paste it into the config." -ForegroundColor Yellow
    exit 1
}

$json = $resp.Content | ConvertFrom-Json
if (-not $json.access_token) { Write-Host "TOKEN_FAILED: response has no access_token." -ForegroundColor Red; exit 1 }
Set-ApiToken -ConfigFile $ConfigFile -Target $Target -Token $json.access_token
$exp = if ($json.expires_in) { " (expires in $([math]::Round($json.expires_in / 60)) min)" } else { '' }
Write-Host "TOKEN_OK: token for '$Target' saved to $ConfigFile$exp. Value not shown." -ForegroundColor Green
