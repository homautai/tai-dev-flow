#Requires -Version 7
<#
.SYNOPSIS
    Save a bearer token (captured from a browser login) into the personal API test config.
.DESCRIPTION
    Writes the token to the field call-api.ps1 reads for that target (new format:
    environments.<env>.bearerToken; legacy: bearerToken / bearerToken_<env>).
    Prints only the expiry, never the token.
.EXAMPLE
    pwsh -File save-token.ps1 -Target dev -Token "<value>"
.EXAMPLE
    $env:DEVFLOW_CAPTURED_TOKEN = "<value>"; pwsh -File save-token.ps1 -Target dev
#>
param(
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$Token = $env:DEVFLOW_CAPTURED_TOKEN,
    [string]$ConfigFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/ApiConfig.ps1')
Set-StrictMode -Off

if (-not $Token) { Write-Host "NO_TOKEN_GIVEN: pass -Token or set DEVFLOW_CAPTURED_TOKEN." -ForegroundColor Yellow; exit 3 }
$Token = $Token.Trim()
if ($Token.StartsWith('Bearer ')) { $Token = $Token.Substring(7) }

if (-not $ConfigFile) {
    $root = Find-ProjectRoot
    $pc = Get-ProjectConfig -ProjectRoot $root
    $rel = Get-OptionalProperty (Get-OptionalProperty $pc 'apiTest') 'configFile'
    if (-not $rel) { $rel = 'docs/API_test/config_swagger.json' }
    $ConfigFile = Join-Path $root $rel
}

$config = Read-ApiConfig $ConfigFile
[void](Resolve-ApiTarget -Config $config -Target $Target)   # fails early on an unknown target
Set-ApiToken -ConfigFile $ConfigFile -Target $Target -Token $Token

$exp = Get-JwtExpiry $Token
$info = if ($exp) { " Expires $($exp.ToLocalTime().ToString('yyyy-MM-dd HH:mm'))." } else { ' Not a JWT, expiry unknown.' }
Write-Host "TOKEN_SAVED for '$Target' in $ConfigFile.$info Value not shown." -ForegroundColor Green
