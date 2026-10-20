# Reads the personal API test config (config_swagger.json). Dot-source this file.
#
# Two formats are supported.
#
# New format (templates/config_swagger.template.json):
#   { "environments": { "local": { "baseUrl": "...", "bearerToken": "..." }, "dev": {...} },
#     "auth": { "tokenUrl": "...", "clientId": "...", "clientSecret": "...", "scope": "...",
#               "users": { "dev": { "username": "...", "password": "..." } } } }
#
# Legacy flat format (what existing projects already use):
#   baseUrl / bearerToken                 -> target "local"
#   baseUrl_<env> / bearerToken_<env>     -> target "<env>" (falls back to bearerToken)
#   baseUrl_<api> / <api>BearerToken      -> extra API, e.g. target "licenseApi"
#   tokenUrl, clientId, clientSecret, username_<env>, pass_<env>
#
# Token override per target: environment variable DEVFLOW_TOKEN_<TARGET> (e.g. DEVFLOW_TOKEN_DEV).

function Read-ApiConfig {
    param([Parameter(Mandatory=$true)][string]$ConfigFile)
    if (-not (Test-Path $ConfigFile)) {
        throw "API config not found: $ConfigFile. Copy templates/config_swagger.template.json there and fill it in (run /setup-project)."
    }
    return Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-NewApiConfigFormat {
    param($Config)
    return $null -ne $Config.PSObject.Properties['environments']
}

function Resolve-ApiTarget {
    param($Config, [Parameter(Mandatory=$true)][string]$Target)

    $t = $Target.Trim()
    $baseUrl = $null; $token = $null; $tokenField = $null

    if (Test-NewApiConfigFormat $Config) {
        $envObj = $Config.environments.PSObject.Properties[$t]
        if ($null -eq $envObj) {
            $names = ($Config.environments.PSObject.Properties | ForEach-Object Name) -join ', '
            throw "Target '$t' not found in environments. Available: $names"
        }
        $baseUrl = $envObj.Value.baseUrl
        $p = $envObj.Value.PSObject.Properties['bearerToken']
        if ($p) { $token = $p.Value }
        $tokenField = "environments.$t.bearerToken"
    }
    else {
        if ($t -eq 'local') {
            $baseUrl = $Config.baseUrl
            $tokenField = 'bearerToken'
        } else {
            $p = $Config.PSObject.Properties["baseUrl_$t"]
            if ($null -eq $p) { throw "Target '$t' not found: expected key 'baseUrl_$t' in the legacy config." }
            $baseUrl = $p.Value
            $tokenField = "bearerToken_$t"
            foreach ($candidate in @("bearerToken_$t", "${t}BearerToken")) {
                $tp = $Config.PSObject.Properties[$candidate]
                if ($tp -and $tp.Value) { $token = $tp.Value; $tokenField = $candidate; break }
            }
        }
        if (-not $token) {
            $tp = $Config.PSObject.Properties['bearerToken']
            if ($tp) { $token = $tp.Value }
        }
    }

    $override = [Environment]::GetEnvironmentVariable("DEVFLOW_TOKEN_$($t.ToUpper())")
    if ($override) { $token = $override; $tokenField = "env:DEVFLOW_TOKEN_$($t.ToUpper())" }

    if (-not $baseUrl) { throw "No baseUrl configured for target '$t'." }
    return [pscustomobject]@{ Target = $t; BaseUrl = ([string]$baseUrl).TrimEnd('/'); Token = $token; TokenField = $tokenField }
}

function Get-ApiAuthSettings {
    param($Config, [Parameter(Mandatory=$true)][string]$Target)
    if (Test-NewApiConfigFormat $Config) {
        $a = $Config.PSObject.Properties['auth']
        if (-not $a) { return $null }
        $auth = $a.Value
        $user = $null; $pass = $null
        $users = $auth.PSObject.Properties['users']
        if ($users -and $users.Value.PSObject.Properties[$Target]) {
            $user = $users.Value.$Target.username; $pass = $users.Value.$Target.password
        }
        $scope = if ($auth.PSObject.Properties['scope']) { $auth.scope } else { $null }
        return [pscustomobject]@{ TokenUrl = $auth.tokenUrl; ClientId = $auth.clientId; ClientSecret = $auth.clientSecret; Scope = $scope; Username = $user; Password = $pass }
    }
    $get = { param($k) $p = $Config.PSObject.Properties[$k]; if ($p) { $p.Value } else { $null } }
    return [pscustomobject]@{
        TokenUrl = & $get 'tokenUrl'; ClientId = & $get 'clientId'; ClientSecret = & $get 'clientSecret'; Scope = & $get 'scope'
        Username = & $get "username_$Target"; Password = & $get "pass_$Target"
    }
}

function Set-ApiToken {
    param([Parameter(Mandatory=$true)][string]$ConfigFile, [Parameter(Mandatory=$true)][string]$Target, [Parameter(Mandatory=$true)][string]$Token)
    $config = Read-ApiConfig $ConfigFile
    if (Test-NewApiConfigFormat $config) {
        $envObj = $config.environments.$Target
        if ($envObj.PSObject.Properties['bearerToken']) { $envObj.bearerToken = $Token }
        else { $envObj | Add-Member -NotePropertyName bearerToken -NotePropertyValue $Token }
    } else {
        $field = if ($Target -eq 'local') { 'bearerToken' } else { "bearerToken_$Target" }
        if ($config.PSObject.Properties[$field]) { $config.$field = $Token }
        else { $config | Add-Member -NotePropertyName $field -NotePropertyValue $Token }
    }
    $config | ConvertTo-Json -Depth 20 | Set-Content -Path $ConfigFile -Encoding utf8
}

function Get-JwtExpiry {
    # Returns the 'exp' claim of a JWT as a UTC DateTime, or $null if the token is not a readable JWT.
    param([string]$Token)
    if (-not $Token) { return $null }
    $parts = $Token.Split('.')
    if ($parts.Count -lt 2) { return $null }
    try {
        $p = $parts[1].Replace('-', '+').Replace('_', '/')
        switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }
        $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
        if ($json.exp) { return [DateTimeOffset]::FromUnixTimeSeconds([long]$json.exp).UtcDateTime }
    } catch { }
    return $null
}

function Get-LoginSettings {
    # Non-secret login info for a target: the UI URL to open and where the app keeps its token.
    param($Config, [Parameter(Mandatory=$true)][string]$Target)
    $url = $null; $from = $null; $key = $null
    if (Test-NewApiConfigFormat $Config) {
        $e = $Config.environments.$Target
        if ($e) {
            $login = $e.PSObject.Properties['login']
            if ($login) { $url = $login.Value.url; $from = $login.Value.tokenFrom; $key = $login.Value.tokenKey }
            if (-not $url -and $e.PSObject.Properties['uiUrl']) { $url = $e.uiUrl }
        }
    } else {
        $p = $Config.PSObject.Properties["baseUrl_${Target}_UI"]
        if ($p) { $url = $p.Value }
    }
    return [pscustomobject]@{ Url = $url; TokenFrom = $from; TokenKey = $key }
}
