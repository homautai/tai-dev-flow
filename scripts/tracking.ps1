#Requires -Version 7
<#
.SYNOPSIS
    Turn automatic timing and the plugin feedback log on or off.
.EXAMPLE
    pwsh -File tracking.ps1 status
    pwsh -File tracking.ps1 off                 # both, for you (all projects)
    pwsh -File tracking.ps1 off -Feature feedback
    pwsh -File tracking.ps1 on  -Project        # write the switch into this project's .dev-flow.json instead
#>
param(
    [Parameter(Mandatory=$true, Position=0)][ValidateSet('on','off','status')][string]$Action,
    [ValidateSet('all','timing','feedback')][string]$Feature = 'all',
    [switch]$Project
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/Common.ps1')
Set-StrictMode -Off
$root = Find-ProjectRoot

if ($Action -ne 'status') {
    $file = if ($Project) { Join-Path $root '.dev-flow.json' } else { Join-Path $HOME '.dev-flow/settings.json' }
    if ($Project -and -not (Test-Path $file)) { throw "No .dev-flow.json in $root. Run setup-project first." }
    $dir = Split-Path -Parent $file; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $obj = if (Test-Path $file) { Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{} }
    if (-not $obj.PSObject.Properties['tracking']) { $obj | Add-Member tracking ([pscustomobject]@{}) }
    $value = ($Action -eq 'on')
    $keys = switch ($Feature) { 'timing' { @('autoTiming') } 'feedback' { @('feedbackLog') } default { @('autoTiming', 'feedbackLog') } }
    foreach ($k in $keys) {
        if ($obj.tracking.PSObject.Properties[$k]) { $obj.tracking.$k = $value } else { $obj.tracking | Add-Member $k $value }
    }
    $obj | ConvertTo-Json -Depth 20 | Set-Content $file -Encoding utf8
    Write-Host "Updated $file"
}
$s = Get-TrackingSettings -ProjectRoot $root
Write-Host ("Tracking for {0}: autoTiming={1}, feedbackLog={2}" -f (Split-Path -Leaf $root), $s.autoTiming, $s.feedbackLog)
