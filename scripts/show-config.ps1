#Requires -Version 7
<#
.SYNOPSIS
    Print a JSON config file with every secret masked. Use this instead of cat/Get-Content
    whenever an agent needs to look at a personal config.
.DESCRIPTION
    Masks values whose key matches token|key|secret|pass|pwd|auth|bearer|cookie|credential|jwt,
    and any string that looks like a JWT (eyJ...) or an Atlassian token (ATATT...), at any depth.
.EXAMPLE
    pwsh -File show-config.ps1 docs/API_test/config_swagger.json
#>
param([Parameter(Mandatory=$true, Position=0)][string]$File)

$ErrorActionPreference = 'Stop'
$keyPattern = '(?i)token|key|secret|pass|pwd|auth|bearer|cookie|credential|jwt'
$safeKeys = @('tokenFrom', 'tokenKey', 'tokenUrl', 'tokenLocalStorageKey', 'reportingCodeId', 'customerId', 'jiraSite')

function Hide($value, [string]$key) {
    if ($null -eq $value) { return $null }
    if ($value -is [System.Management.Automation.PSCustomObject]) {
        $o = [ordered]@{}
        foreach ($p in $value.PSObject.Properties) { $o[$p.Name] = Hide $p.Value $p.Name }
        return [pscustomobject]$o
    }
    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) { return @($value | ForEach-Object { Hide $_ $key }) }
    if ($value -is [string]) {
        $secretKey = ($key -match $keyPattern) -and ($safeKeys -notcontains $key)
        if (($secretKey -and $value.Length -gt 0) -or $value -match '^(Bearer )?eyJ[\w-]+\.' -or $value -match '^ATATT') {
            return "<hidden, $($value.Length) chars>"
        }
    }
    return $value
}

$json = Get-Content $File -Raw -Encoding UTF8 | ConvertFrom-Json
Hide $json '' | ConvertTo-Json -Depth 20
