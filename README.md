# AgentSpan Skills for AI Coding Agents

> AI agents that don't die when your process dies.

Teach your AI coding agent how to build, run, monitor, and manage durable AI agents with [AgentSpan](https://github.com/agentspan/agentspan).

## What this provides

- **Build agents** — Create agents with tools, guardrails, and structured output using the Python SDK
- **Multi-agent teams** — Sequential pipelines, parallel execution, routers, swarm orchestration
- **Run and monitor** — Start agents, stream events, search executions, check status
- **Human-in-the-loop** — Durable approval workflows that pause for days, not minutes
- **Credentials** — Encrypted server-side credential management
- **Framework compatibility** — Works with LangGraph, OpenAI Agents SDK, Google ADK

## Quick install

### Claude Code plugin

```
/plugin marketplace add agentspan/agentspan-skills
/plugin install agentspan@agentspan-skills
```

### Shell installer (all agents)

macOS / Linux:

```bash
curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh | bash -s -- --all
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.ps1 -OutFile install.ps1; .\install.ps1 -All
```

### Per-agent install

| Agent | Command |
|-------|---------|
| Claude Code | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent claude` |
| Codex | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent codex` |
| Gemini CLI | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent gemini` |
| Cursor | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent cursor` |
| Windsurf | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent windsurf` |
| Cline | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent cline` |
| Copilot | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent copilot` |
| Aider | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent aider` |
| Amazon Q | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent amazonq` |
| Roo | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent roo` |
| Amp | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent amp` |
| OpenCode | `curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh \| bash -s -- --agent opencode` |

## Example prompts

Try these after installing:

- "Create an agent that searches the web and summarizes results"
- "Build a research team with a researcher and writer working in sequence"
- "Create an agent with human approval for file deletions"
- "Show me all failed agent executions from today"
- "Stream events from my running agent"
- "Create an agent that returns structured JSON output"
- "Set up credentials for my GitHub token"

## Documentation

- [SKILL.md](skills/agentspan/SKILL.md) — Core skill definition
- [SDK Reference](skills/agentspan/references/sdk-reference.md) — Python SDK API
- [CLI Reference](skills/agentspan/references/cli-reference.md) — CLI commands
- [API Reference](skills/agentspan/references/api-reference.md) — REST API

### Examples

- [Create and run an agent](skills/agentspan/examples/create-and-run-agent.md)
- [Multi-agent team](skills/agentspan/examples/multi-agent-team.md)
- [Human-in-the-loop approval](skills/agentspan/examples/hitl-approval.md)
- [Monitor and debug](skills/agentspan/examples/monitor-and-debug.md)

## Upgrade

```bash
curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh | bash -s -- --all --upgrade
```

## Uninstall

```bash
curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh | bash -s -- --all --uninstall
```

## Evaluations

Run the eval suite to test skill quality across LLM providers:

```bash
python3 scripts/run_evals.py --verbose
```

See [evaluations/README.md](evaluations/README.md) for details.

## Supported agents

| Agent | Status |
|-------|--------|
| Claude Code | Supported (plugin + installer) |
| Codex | Supported |
| Gemini CLI | Supported |
| Cursor | Supported |
| Windsurf | Supported |
| Cline | Supported |
| GitHub Copilot | Supported |
| Aider | Supported |
| Amazon Q | Supported |
| Roo | Supported |
| Amp | Supported |
| OpenCode | Supported |

## License

MIT — see [LICENSE.txt](LICENSE.txt)
