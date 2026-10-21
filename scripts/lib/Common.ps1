# Shared helpers for tai-dev-flow scripts. Dot-source this file.
#
# Secrets are NEVER read from the plugin folder. Lookup order for Atlassian credentials:
#   1. Environment variables: DEVFLOW_ATLASSIAN_EMAIL, DEVFLOW_JIRA_API_TOKEN, DEVFLOW_BITBUCKET_API_TOKEN
#   2. Personal file:         ~/.dev-flow/credentials.json   (see templates/credentials.template.json)
#   3. Legacy project file:   <project>/.jira/config.json     (email, api_token, api_pr)

Set-StrictMode -Version Latest

function Find-ProjectRoot {
    param([string]$Start = (Get-Location).Path)
    $dir = Resolve-Path $Start
    $current = $dir.Path
    while ($current) {
        if ((Test-Path (Join-Path $current '.dev-flow.json')) -or (Test-Path (Join-Path $current '.git'))) {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    return $dir.Path
}

function Get-ProjectConfig {
    param([string]$ProjectRoot = (Find-ProjectRoot))
    $file = Join-Path $ProjectRoot '.dev-flow.json'
    if (-not (Test-Path $file)) { return $null }
    return Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-OptionalProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-AtlassianCredentials {
    param([string]$ProjectRoot = (Find-ProjectRoot), [string]$SiteHost)

    $result = [ordered]@{ Email = $null; JiraToken = $null; BitbucketToken = $null; Source = $null }

    # 0. Per-site override in the personal file: atlassian.sites["<host>"] = { email, jiraApiToken }
    if ($SiteHost) {
        $personal = Join-Path $HOME '.dev-flow/credentials.json'
        if (Test-Path $personal) {
            $c = Get-Content $personal -Raw -Encoding UTF8 | ConvertFrom-Json
            $sites = Get-OptionalProperty (Get-OptionalProperty $c 'atlassian') 'sites'
            $site = Get-OptionalProperty $sites $SiteHost
            if ($site) {
                $result.Email = Get-OptionalProperty $site 'email'
                $result.JiraToken = Get-OptionalProperty $site 'jiraApiToken'
                $result.Source = "$personal (sites.$SiteHost)"
                return [pscustomobject]$result
            }
        }
    }

    # 1. Environment variables
    if ($env:DEVFLOW_ATLASSIAN_EMAIL) {
        $result.Email = $env:DEVFLOW_ATLASSIAN_EMAIL
        $result.JiraToken = $env:DEVFLOW_JIRA_API_TOKEN
        $result.BitbucketToken = $env:DEVFLOW_BITBUCKET_API_TOKEN
        $result.Source = 'environment variables'
    }

    # 2. Personal credentials file
    if (-not $result.Email) {
        $personal = Join-Path $HOME '.dev-flow/credentials.json'
        if (Test-Path $personal) {
            $c = Get-Content $personal -Raw -Encoding UTF8 | ConvertFrom-Json
            $a = Get-OptionalProperty $c 'atlassian'
            $result.Email = Get-OptionalProperty $a 'email'
            $result.JiraToken = Get-OptionalProperty $a 'jiraApiToken'
            $result.BitbucketToken = Get-OptionalProperty $a 'bitbucketApiToken'
            $result.Source = $personal
        }
    }

    # 3. Legacy per-project file
    if (-not $result.Email) {
        $legacy = Join-Path $ProjectRoot '.jira/config.json'
        if (Test-Path $legacy) {
            $c = Get-Content $legacy -Raw -Encoding UTF8 | ConvertFrom-Json
            $result.Email = Get-OptionalProperty $c 'email'
            $result.JiraToken = Get-OptionalProperty $c 'api_token'
            $result.BitbucketToken = Get-OptionalProperty $c 'api_pr'
            $result.Source = "$legacy (legacy)"
        }
    }

    $placeholders = @('', 'your-email@domain.com', 'YOUR_JIRA_API_TOKEN', 'YOUR_BITBUCKET_API_TOKEN')
    foreach ($key in @('Email', 'JiraToken', 'BitbucketToken')) {
        if ($placeholders -contains [string]$result[$key]) { $result[$key] = $null }
    }
    return [pscustomobject]$result
}

function New-BasicAuthHeaders {
    param([string]$User, [string]$Secret, [hashtable]$Extra = @{})
    $pair = "${User}:${Secret}"
    $base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))
    $headers = @{ Authorization = "Basic $base64"; Accept = 'application/json' }
    foreach ($k in $Extra.Keys) { $headers[$k] = $Extra[$k] }
    return $headers
}

function Get-JiraBaseUrl {
    param([string]$Override, $ProjectConfig)
    if ($Override) { return $Override.TrimEnd('/') }
    $jira = Get-OptionalProperty $ProjectConfig 'jira'
    $url = Get-OptionalProperty $jira 'baseUrl'
    if ($url) { return ([string]$url).TrimEnd('/') }
    if ($env:DEVFLOW_JIRA_BASE_URL) { return $env:DEVFLOW_JIRA_BASE_URL.TrimEnd('/') }
    throw "Jira base URL not configured. Set jira.baseUrl in .dev-flow.json (run /setup-project) or pass -JiraBaseUrl."
}

function Get-CacheDir {
    param([string]$ProjectRoot = (Find-ProjectRoot), [string]$Override)
    $dir = if ($Override) { $Override } else { Join-Path $ProjectRoot '.dev-flow/cache' }
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Get-MaskedValue {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '<empty>' }
    return "<hidden, $($Value.Length) chars>"
}

function Get-TrackingSettings {
    # Tracking switches. Personal default: ~/.dev-flow/settings.json { "tracking": { "autoTiming": true, "feedbackLog": true } }
    # A project's .dev-flow.json "tracking" block overrides it. Missing = enabled.
    param([string]$ProjectRoot)
    $result = [ordered]@{ autoTiming = $true; feedbackLog = $true }
    $personal = Join-Path $HOME '.dev-flow/settings.json'
    $sources = @()
    if (Test-Path $personal) { try { $sources += (Get-Content $personal -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { } }
    if ($ProjectRoot) { $pc = Get-ProjectConfig -ProjectRoot $ProjectRoot; if ($pc) { $sources += $pc } }
    foreach ($s in $sources) {
        $t = Get-OptionalProperty $s 'tracking'
        foreach ($k in @('autoTiming', 'feedbackLog')) {
            $v = Get-OptionalProperty $t $k
            if ($null -ne $v) { $result[$k] = [bool]$v }
        }
    }
    return [pscustomobject]$result
}
