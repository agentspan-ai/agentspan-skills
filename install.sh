#!/usr/bin/env bash
set -euo pipefail

# AgentSpan Skills Installer
# Installs AgentSpan skill files for AI coding agents.
#
# Usage:
#   curl -sSL https://agentspan.github.io/agentspan-skills/install.sh | bash -s -- --all
#   curl -sSL https://agentspan.github.io/agentspan-skills/install.sh | bash -s -- --agent claude
#   curl -sSL https://agentspan.github.io/agentspan-skills/install.sh | bash -s -- --all --upgrade
#   curl -sSL https://agentspan.github.io/agentspan-skills/install.sh | bash -s -- --all --uninstall

REPO_URL="https://raw.githubusercontent.com/agentspan/agentspan-skills/main"
VERSION_URL="https://raw.githubusercontent.com/agentspan/agentspan-skills/main/VERSION"

SKILL_FILES=(
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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC} $1"; }
ok()    { echo -e "${GREEN}[ok]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
err()   { echo -e "${RED}[error]${NC} $1"; }

# Defaults
AGENT=""
ALL=false
UPGRADE=false
UNINSTALL=false
CHECK=false
FORCE=false
GLOBAL=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --agent)   AGENT="$2"; shift 2 ;;
    --all)     ALL=true; shift ;;
    --upgrade) UPGRADE=true; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    --check)   CHECK=true; shift ;;
    --force)   FORCE=true; shift ;;
    --global)  GLOBAL=true; shift ;;
    -h|--help) echo "Usage: install.sh [--agent NAME|--all] [--upgrade|--uninstall|--check|--force|--global]"; exit 0 ;;
    *) err "Unknown flag: $1"; exit 1 ;;
  esac
done

# Agent detection and install paths
declare -A AGENT_PATHS
detect_agents() {
  # Claude Code
  if command -v claude &>/dev/null || [[ -d "$HOME/.claude" ]]; then
    AGENT_PATHS[claude]="$HOME/.claude/plugins/agentspan-skills"
  fi
  # Codex
  if command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]]; then
    AGENT_PATHS[codex]="$HOME/.codex/instructions"
  fi
  # Gemini CLI
  if command -v gemini &>/dev/null || [[ -d "$HOME/.gemini" ]]; then
    AGENT_PATHS[gemini]="$HOME/.gemini/instructions"
  fi
  # Cursor
  if [[ -d "$HOME/.cursor" ]] || [[ -d "$HOME/Library/Application Support/Cursor" ]]; then
    AGENT_PATHS[cursor]="$HOME/.cursor/rules"
  fi
  # Windsurf
  if [[ -d "$HOME/.codeium" ]] || [[ -d "$HOME/.windsurf" ]]; then
    AGENT_PATHS[windsurf]="$HOME/.windsurf/rules"
  fi
  # Cline
  if [[ -d "$HOME/.cline" ]]; then
    AGENT_PATHS[cline]="$HOME/.cline/instructions"
  fi
  # Aider
  if command -v aider &>/dev/null || [[ -d "$HOME/.aider" ]]; then
    AGENT_PATHS[aider]="$HOME/.aider/instructions"
  fi
  # GitHub Copilot
  if [[ -d "$HOME/.config/github-copilot" ]]; then
    AGENT_PATHS[copilot]="$HOME/.config/github-copilot/instructions"
  fi
  # Amazon Q
  if command -v q &>/dev/null || [[ -d "$HOME/.amazonq" ]]; then
    AGENT_PATHS[amazonq]="$HOME/.amazonq/instructions"
  fi
  # Roo
  if [[ -d "$HOME/.roo" ]]; then
    AGENT_PATHS[roo]="$HOME/.roo/instructions"
  fi
  # Amp
  if command -v amp &>/dev/null || [[ -d "$HOME/.amp" ]]; then
    AGENT_PATHS[amp]="$HOME/.amp/instructions"
  fi
  # OpenCode
  if command -v opencode &>/dev/null || [[ -d "$HOME/.opencode" ]]; then
    AGENT_PATHS[opencode]="$HOME/.opencode/instructions"
  fi
}

get_remote_version() {
  curl -sSL "$VERSION_URL" 2>/dev/null || echo "unknown"
}

get_local_version() {
  local manifest="$1/.agentspan-skills-manifest"
  if [[ -f "$manifest" ]]; then
    grep "version=" "$manifest" 2>/dev/null | cut -d= -f2
  else
    echo ""
  fi
}

download_file() {
  local src="$REPO_URL/$1"
  local dst="$2/$1"
  mkdir -p "$(dirname "$dst")"
  if curl -sSL "$src" -o "$dst" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

install_for_agent() {
  local agent_name="$1"
  local install_path="$2"
  local remote_version
  remote_version=$(get_remote_version)

  if $UNINSTALL; then
    if [[ -d "$install_path" ]]; then
      rm -rf "$install_path"
      ok "Uninstalled from $agent_name"
    else
      warn "$agent_name: not installed"
    fi
    return
  fi

  if $CHECK; then
    local local_version
    local_version=$(get_local_version "$install_path")
    if [[ -z "$local_version" ]]; then
      info "$agent_name: not installed (available: $remote_version)"
    elif [[ "$local_version" == "$remote_version" ]]; then
      ok "$agent_name: up to date ($local_version)"
    else
      warn "$agent_name: update available ($local_version -> $remote_version)"
    fi
    return
  fi

  if $UPGRADE; then
    local local_version
    local_version=$(get_local_version "$install_path")
    if [[ "$local_version" == "$remote_version" ]] && ! $FORCE; then
      ok "$agent_name: already up to date ($local_version)"
      return
    fi
  fi

  if [[ -d "$install_path" ]] && ! $FORCE && ! $UPGRADE; then
    warn "$agent_name: already installed (use --upgrade or --force)"
    return
  fi

  info "Installing for $agent_name -> $install_path"

  local failed=0
  for file in "${SKILL_FILES[@]}"; do
    if download_file "$file" "$install_path"; then
      ok "  $file"
    else
      err "  Failed: $file"
      ((failed++))
    fi
  done

  # Write manifest
  cat > "$install_path/.agentspan-skills-manifest" << EOF
version=$remote_version
installed=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
agent=$agent_name
EOF

  if [[ $failed -eq 0 ]]; then
    ok "Installed for $agent_name ($remote_version)"
  else
    warn "Installed with $failed errors"
  fi
}

# Main
detect_agents

if $ALL; then
  if [[ ${#AGENT_PATHS[@]} -eq 0 ]]; then
    warn "No supported agents detected on this system."
    info "Supported: claude, codex, gemini, cursor, windsurf, cline, aider, copilot, amazonq, roo, amp, opencode"
    exit 1
  fi
  info "Detected ${#AGENT_PATHS[@]} agent(s): ${!AGENT_PATHS[*]}"
  for agent_name in "${!AGENT_PATHS[@]}"; do
    install_for_agent "$agent_name" "${AGENT_PATHS[$agent_name]}"
  done
elif [[ -n "$AGENT" ]]; then
  # For specific agent, set path even if not auto-detected
  if [[ -z "${AGENT_PATHS[$AGENT]+x}" ]]; then
    case $AGENT in
      claude)   AGENT_PATHS[$AGENT]="$HOME/.claude/plugins/agentspan-skills" ;;
      codex)    AGENT_PATHS[$AGENT]="$HOME/.codex/instructions" ;;
      gemini)   AGENT_PATHS[$AGENT]="$HOME/.gemini/instructions" ;;
      cursor)   AGENT_PATHS[$AGENT]="$HOME/.cursor/rules" ;;
      windsurf) AGENT_PATHS[$AGENT]="$HOME/.windsurf/rules" ;;
      cline)    AGENT_PATHS[$AGENT]="$HOME/.cline/instructions" ;;
      aider)    AGENT_PATHS[$AGENT]="$HOME/.aider/instructions" ;;
      copilot)  AGENT_PATHS[$AGENT]="$HOME/.config/github-copilot/instructions" ;;
      amazonq)  AGENT_PATHS[$AGENT]="$HOME/.amazonq/instructions" ;;
      roo)      AGENT_PATHS[$AGENT]="$HOME/.roo/instructions" ;;
      amp)      AGENT_PATHS[$AGENT]="$HOME/.amp/instructions" ;;
      opencode) AGENT_PATHS[$AGENT]="$HOME/.opencode/instructions" ;;
      *) err "Unknown agent: $AGENT"; exit 1 ;;
    esac
  fi
  install_for_agent "$AGENT" "${AGENT_PATHS[$AGENT]}"
else
  echo "AgentSpan Skills Installer"
  echo ""
  echo "Usage:"
  echo "  install.sh --all              Install for all detected agents"
  echo "  install.sh --agent claude     Install for a specific agent"
  echo "  install.sh --all --upgrade    Upgrade all installations"
  echo "  install.sh --all --uninstall  Remove all installations"
  echo "  install.sh --all --check      Check install status (dry run)"
  echo ""
  detect_agents
  if [[ ${#AGENT_PATHS[@]} -gt 0 ]]; then
    info "Detected agents: ${!AGENT_PATHS[*]}"
  else
    warn "No agents detected"
  fi
  echo ""
  echo "Supported: claude, codex, gemini, cursor, windsurf, cline, aider, copilot, amazonq, roo, amp, opencode"
fi
