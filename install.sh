#!/usr/bin/env bash
set -euo pipefail

# AgentSpan Skills Installer
# Works on macOS (bash 3.x) and Linux (bash 4+).
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

# Agent path lookup (bash 3 compatible — no associative arrays)
get_agent_path() {
  case "$1" in
    claude)   echo "$HOME/.claude/plugins/agentspan-skills" ;;
    codex)    echo "$HOME/.codex/instructions" ;;
    gemini)   echo "$HOME/.gemini/instructions" ;;
    cursor)   echo "$HOME/.cursor/rules" ;;
    windsurf) echo "$HOME/.windsurf/rules" ;;
    cline)    echo "$HOME/.cline/instructions" ;;
    aider)    echo "$HOME/.aider/instructions" ;;
    copilot)  echo "$HOME/.config/github-copilot/instructions" ;;
    amazonq)  echo "$HOME/.amazonq/instructions" ;;
    roo)      echo "$HOME/.roo/instructions" ;;
    amp)      echo "$HOME/.amp/instructions" ;;
    opencode) echo "$HOME/.opencode/instructions" ;;
    *) echo "" ;;
  esac
}

ALL_AGENTS="claude codex gemini cursor windsurf cline aider copilot amazonq roo amp opencode"

detect_agents() {
  local detected=""
  for agent_name in $ALL_AGENTS; do
    local found=false
    case "$agent_name" in
      claude)   command -v claude &>/dev/null || [[ -d "$HOME/.claude" ]] && found=true ;;
      codex)    command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]] && found=true ;;
      gemini)   command -v gemini &>/dev/null || [[ -d "$HOME/.gemini" ]] && found=true ;;
      cursor)   [[ -d "$HOME/.cursor" ]] || [[ -d "$HOME/Library/Application Support/Cursor" ]] && found=true ;;
      windsurf) [[ -d "$HOME/.codeium" ]] || [[ -d "$HOME/.windsurf" ]] && found=true ;;
      cline)    [[ -d "$HOME/.cline" ]] && found=true ;;
      aider)    command -v aider &>/dev/null || [[ -d "$HOME/.aider" ]] && found=true ;;
      copilot)  [[ -d "$HOME/.config/github-copilot" ]] && found=true ;;
      amazonq)  command -v q &>/dev/null || [[ -d "$HOME/.amazonq" ]] && found=true ;;
      roo)      [[ -d "$HOME/.roo" ]] && found=true ;;
      amp)      command -v amp &>/dev/null || [[ -d "$HOME/.amp" ]] && found=true ;;
      opencode) command -v opencode &>/dev/null || [[ -d "$HOME/.opencode" ]] && found=true ;;
    esac
    if $found; then
      detected="$detected $agent_name"
    fi
  done
  echo "$detected"
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
  local install_path
  install_path=$(get_agent_path "$agent_name")

  if [[ -z "$install_path" ]]; then
    err "Unknown agent: $agent_name"
    return 1
  fi

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
      failed=$((failed + 1))
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
if $ALL; then
  DETECTED=$(detect_agents)
  if [[ -z "$DETECTED" ]]; then
    warn "No supported agents detected on this system."
    info "Supported: $ALL_AGENTS"
    exit 1
  fi
  info "Detected agents:$DETECTED"
  for agent_name in $DETECTED; do
    install_for_agent "$agent_name"
  done
elif [[ -n "$AGENT" ]]; then
  install_for_agent "$AGENT"
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
  DETECTED=$(detect_agents)
  if [[ -n "$DETECTED" ]]; then
    info "Detected agents:$DETECTED"
  else
    warn "No agents detected"
  fi
  echo ""
  echo "Supported: $ALL_AGENTS"
fi
