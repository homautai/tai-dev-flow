<#
.SYNOPSIS
    PreToolUse guard (Claude Code hook) for shell tools: blocks commands that could wipe local-only work.
.DESCRIPTION
    Blocks (exit 2, reason on stderr, so Claude sees it and must ask the user):
      - any `git clean`
      - recursive / forced deletes (rm -r, rm -rf, rmdir, rd /s, del /s, Remove-Item, [IO.Directory]::Delete …)
        that mention a protected place: a registered workspace or ticket folder, a ".dev-flow" folder, the user's
        ~/.dev-flow, a parent path (".."), or an absolute path outside the current repo.
    Deletes of repo-relative paths inside the repo are allowed. Always on (not affected by tracking switches).
    Never fails the tool call because of its own errors: any internal error = allow.
#>
$ErrorActionPreference = 'Stop'
try {
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw.Trim()) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $cmd = [string]$in.tool_input.command
    if (-not $cmd) { exit 0 }

    function Norm([string]$s) {
        $s = $s.ToLowerInvariant().Replace('\', '/')
        $s = [regex]::Replace($s, '(^|[\s"''=(])/([a-z])/', '$1$2:/')   # git-bash /d/... -> d:/...
        return $s
    }
    $c = Norm $cmd

    $deleteRx = '(\bgit\s+clean\b)|(\brm\s+(-[a-z]*[rf][a-z]*\s+)+)|(\brm\s+--recursive\b)|(\brmdir\b)|(\brd\s+/s\b)|(\bdel\s+/[sq])|(\bremove-item\b)|(\b(ri|rm|del|erase)\s+.*-recurse\b)|(\[(system\.)?io\.directory\]::delete)|(shutil\.rmtree)|(\bfind\b.*-delete\b)'
    if ($c -notmatch $deleteRx) { exit 0 }

    $reason = $null
    if ($c -match '\bgit\s+clean\b') { $reason = 'git clean can delete untracked and ignored files (ticket folders, configs).' }
    else {
        $protected = @('.dev-flow', '~/.dev-flow', '$home/.dev-flow', '%userprofile%/.dev-flow', '/..', ' ..', '"..', '../')
        $regFile = Join-Path $HOME '.dev-flow/tracking/workspaces.json'
        if (Test-Path $regFile) {
            foreach ($w in @(Get-Content $regFile -Raw | ConvertFrom-Json)) {
                foreach ($p in @($w.ticketsDir, $w.workspaceRoot)) { if ($p) { $protected += (Norm $p) } }
            }
        }
        foreach ($p in $protected) { if ($c.Contains($p)) { $reason = "it targets a protected location ($p)."; break } }

        if (-not $reason) {
            . (Join-Path $PSScriptRoot '../lib/Common.ps1')
            Set-StrictMode -Off
            $start = if ($in.cwd) { [string]$in.cwd } else { (Get-Location).Path }
            $repoRaw = Find-ProjectRoot -Start $start
            if (-not (Test-Path (Join-Path $repoRaw '.git'))) {
                $reason = 'the current folder is not inside a git repo, so the delete is not limited to code under version control.'
            } else {
                # Absolute paths must stay inside the current repo
                $repo = (Norm $repoRaw).TrimEnd('/')
                $paths = @()
                foreach ($m in [regex]::Matches($c, '"([a-z]:/[^"]*)"|''([a-z]:/[^'']*)''|(?<![\w"''])([a-z]:/[^\s"''`;|&]*)')) {
                    $paths += ($m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value)
                }
                foreach ($path in $paths) {
                    $path = $path.TrimEnd('/')
                    if (-not $path.StartsWith($repo + '/')) { $reason = "it deletes an absolute path outside this repo ($path)."; break }
                }
            }
        }
    }

    if ($reason) {
        [Console]::Error.WriteLine("Blocked by tai-dev-flow: this command may delete files outside the ticket's code — $reason " +
            "Do not retry or work around it. Explain to the user what should be deleted and why, and let them run it themselves.")
        exit 2
    }
    exit 0
} catch {
    exit 0
}
