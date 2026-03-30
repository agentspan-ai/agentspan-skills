# AgentSpan Skills Installer (Windows)
# Usage:
#   .\install.ps1 -All
#   .\install.ps1 -Agent claude
#   .\install.ps1 -All -Upgrade
#   .\install.ps1 -All -Uninstall

param(
    [string]$Agent = "",
    [switch]$All,
    [switch]$Upgrade,
    [switch]$Uninstall,
    [switch]$Check,
    [switch]$Force,
    [switch]$Global
)

$ErrorActionPreference = "Stop"

$RepoUrl = "https://raw.githubusercontent.com/agentspan/agentspan-skills/main"
$VersionUrl = "https://raw.githubusercontent.com/agentspan/agentspan-skills/main/VERSION"

$SkillFiles = @(
    "skills/agentspan/SKILL.md"
    "skills/agentspan/references/sdk-reference.md"
    "skills/agentspan/references/cli-reference.md"
    "skills/agentspan/references/api-reference.md"
    "skills/agentspan/examples/create-and-run-agent.md"
    "skills/agentspan/examples/multi-agent-team.md"
    "skills/agentspan/examples/hitl-approval.md"
    "skills/agentspan/examples/monitor-and-debug.md"
    "skills/agentspan/scripts/agentspan_api.py"
)

function Write-Info  { param($msg) Write-Host "[info] $msg" -ForegroundColor Blue }
function Write-Ok    { param($msg) Write-Host "[ok] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[warn] $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[error] $msg" -ForegroundColor Red }

function Get-AgentPaths {
    $paths = @{}
    $home = $env:USERPROFILE

    if ((Get-Command "claude" -ErrorAction SilentlyContinue) -or (Test-Path "$home\.claude")) {
        $paths["claude"] = "$home\.claude\plugins\agentspan-skills"
    }
    if ((Get-Command "codex" -ErrorAction SilentlyContinue) -or (Test-Path "$home\.codex")) {
        $paths["codex"] = "$home\.codex\instructions"
    }
    if ((Get-Command "gemini" -ErrorAction SilentlyContinue) -or (Test-Path "$home\.gemini")) {
        $paths["gemini"] = "$home\.gemini\instructions"
    }
    if (Test-Path "$home\.cursor") {
        $paths["cursor"] = "$home\.cursor\rules"
    }
    if ((Test-Path "$home\.codeium") -or (Test-Path "$home\.windsurf")) {
        $paths["windsurf"] = "$home\.windsurf\rules"
    }
    if (Test-Path "$home\.cline") {
        $paths["cline"] = "$home\.cline\instructions"
    }
    if ((Get-Command "aider" -ErrorAction SilentlyContinue) -or (Test-Path "$home\.aider")) {
        $paths["aider"] = "$home\.aider\instructions"
    }
    if (Test-Path "$home\.config\github-copilot") {
        $paths["copilot"] = "$home\.config\github-copilot\instructions"
    }
    if ((Get-Command "q" -ErrorAction SilentlyContinue) -or (Test-Path "$home\.amazonq")) {
        $paths["amazonq"] = "$home\.amazonq\instructions"
    }
    if (Test-Path "$home\.roo") {
        $paths["roo"] = "$home\.roo\instructions"
    }
    if ((Get-Command "amp" -ErrorAction SilentlyContinue) -or (Test-Path "$home\.amp")) {
        $paths["amp"] = "$home\.amp\instructions"
    }
    if ((Get-Command "opencode" -ErrorAction SilentlyContinue) -or (Test-Path "$home\.opencode")) {
        $paths["opencode"] = "$home\.opencode\instructions"
    }

    return $paths
}

function Get-RemoteVersion {
    try { return (Invoke-RestMethod $VersionUrl).Trim() }
    catch { return "unknown" }
}

function Get-LocalVersion {
    param($InstallPath)
    $manifest = Join-Path $InstallPath ".agentspan-skills-manifest"
    if (Test-Path $manifest) {
        $content = Get-Content $manifest
        foreach ($line in $content) {
            if ($line -match "^version=(.+)$") { return $Matches[1] }
        }
    }
    return ""
}

function Install-ForAgent {
    param($AgentName, $InstallPath)

    $remoteVersion = Get-RemoteVersion

    if ($Uninstall) {
        if (Test-Path $InstallPath) {
            Remove-Item -Recurse -Force $InstallPath
            Write-Ok "Uninstalled from $AgentName"
        } else {
            Write-Warn "$AgentName`: not installed"
        }
        return
    }

    if ($Check) {
        $localVersion = Get-LocalVersion $InstallPath
        if (-not $localVersion) {
            Write-Info "$AgentName`: not installed (available: $remoteVersion)"
        } elseif ($localVersion -eq $remoteVersion) {
            Write-Ok "$AgentName`: up to date ($localVersion)"
        } else {
            Write-Warn "$AgentName`: update available ($localVersion -> $remoteVersion)"
        }
        return
    }

    if ($Upgrade) {
        $localVersion = Get-LocalVersion $InstallPath
        if ($localVersion -eq $remoteVersion -and -not $Force) {
            Write-Ok "$AgentName`: already up to date ($localVersion)"
            return
        }
    }

    if ((Test-Path $InstallPath) -and -not $Force -and -not $Upgrade) {
        Write-Warn "$AgentName`: already installed (use -Upgrade or -Force)"
        return
    }

    Write-Info "Installing for $AgentName -> $InstallPath"

    $failed = 0
    foreach ($file in $SkillFiles) {
        $src = "$RepoUrl/$file"
        $dst = Join-Path $InstallPath $file
        $dstDir = Split-Path $dst -Parent
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        try {
            Invoke-RestMethod $src -OutFile $dst
            Write-Ok "  $file"
        } catch {
            Write-Err "  Failed: $file"
            $failed++
        }
    }

    $manifest = Join-Path $InstallPath ".agentspan-skills-manifest"
    @"
version=$remoteVersion
installed=$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
agent=$AgentName
"@ | Set-Content $manifest

    if ($failed -eq 0) {
        Write-Ok "Installed for $AgentName ($remoteVersion)"
    } else {
        Write-Warn "Installed with $failed errors"
    }
}

# Main
$agentPaths = Get-AgentPaths

if ($All) {
    if ($agentPaths.Count -eq 0) {
        Write-Warn "No supported agents detected."
        Write-Info "Supported: claude, codex, gemini, cursor, windsurf, cline, aider, copilot, amazonq, roo, amp, opencode"
        exit 1
    }
    Write-Info "Detected $($agentPaths.Count) agent(s): $($agentPaths.Keys -join ', ')"
    foreach ($name in $agentPaths.Keys) {
        Install-ForAgent $name $agentPaths[$name]
    }
} elseif ($Agent) {
    $home = $env:USERPROFILE
    if (-not $agentPaths.ContainsKey($Agent)) {
        $fallback = @{
            "claude"   = "$home\.claude\plugins\agentspan-skills"
            "codex"    = "$home\.codex\instructions"
            "gemini"   = "$home\.gemini\instructions"
            "cursor"   = "$home\.cursor\rules"
            "windsurf" = "$home\.windsurf\rules"
            "cline"    = "$home\.cline\instructions"
            "aider"    = "$home\.aider\instructions"
            "copilot"  = "$home\.config\github-copilot\instructions"
            "amazonq"  = "$home\.amazonq\instructions"
            "roo"      = "$home\.roo\instructions"
            "amp"      = "$home\.amp\instructions"
            "opencode" = "$home\.opencode\instructions"
        }
        if ($fallback.ContainsKey($Agent)) {
            $agentPaths[$Agent] = $fallback[$Agent]
        } else {
            Write-Err "Unknown agent: $Agent"
            exit 1
        }
    }
    Install-ForAgent $Agent $agentPaths[$Agent]
} else {
    Write-Host "AgentSpan Skills Installer"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\install.ps1 -All              Install for all detected agents"
    Write-Host "  .\install.ps1 -Agent claude      Install for a specific agent"
    Write-Host "  .\install.ps1 -All -Upgrade      Upgrade all installations"
    Write-Host "  .\install.ps1 -All -Uninstall    Remove all installations"
    Write-Host "  .\install.ps1 -All -Check        Check install status (dry run)"
    Write-Host ""
    if ($agentPaths.Count -gt 0) {
        Write-Info "Detected agents: $($agentPaths.Keys -join ', ')"
    } else {
        Write-Warn "No agents detected"
    }
    Write-Host ""
    Write-Host "Supported: claude, codex, gemini, cursor, windsurf, cline, aider, copilot, amazonq, roo, amp, opencode"
}
