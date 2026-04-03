# AgentSpan CLI Reference

## Installation

```bash
npm install -g @agentspan-ai/agentspan
```

## Server management

### Start server

```bash
agentspan server start [--port 6767] [--model openai/gpt-4o]
```

Starts the local AgentSpan runtime server. Auto-downloads the server JAR if not cached.

### Stop server

```bash
agentspan server stop
```

### Server logs

```bash
agentspan server logs [-f]
```

`-f` follows the log output in real-time.

## Agent commands

### Run an agent

```bash
agentspan agent run --name <agent-name> "prompt"
agentspan agent run --config <agent.yaml> "prompt"
```

| Flag | Description |
|------|-------------|
| `--name` | Run a deployed agent by name |
| `--config` | Run from a YAML/JSON config file |
| `--sync` | Wait for completion (default) |
| `--async` | Return execution ID immediately |

### List agents

```bash
agentspan agent list
```

Lists all registered agent definitions on the server.

### Get agent definition

```bash
agentspan agent get <name>
```

Returns the agent's compiled workflow definition as JSON.

### Delete agent

```bash
agentspan agent delete <name>
```

### Compile agent config

```bash
agentspan agent compile <agent.yaml>
```

Compiles config to workflow JSON (inspect only, does not register).

### Initialize agent config

```bash
agentspan agent init <name>
```

Generates a starter YAML config file.

### Agent status

```bash
agentspan agent status <execution-id>
```

Detailed execution status including task-level details.

### Search executions

```bash
agentspan agent execution [flags]
```

| Flag | Description |
|------|-------------|
| `--status` | Filter by status: RUNNING, COMPLETED, FAILED, TERMINATED, TIMED_OUT, PAUSED |
| `--since` | Time filter: 1h, 1d, 7d, 30d |
| `--name` | Filter by agent name |
| `--limit` | Max results (default 10) |

### Stream events

```bash
agentspan agent stream <execution-id>
```

Streams SSE events in real-time: `tool_call`, `thinking`, `guardrail_pass`, `guardrail_fail`, `done`.

### Respond to HITL

```bash
agentspan agent respond <execution-id> --approve
agentspan agent respond <execution-id> --deny --reason "Not ready"
agentspan agent respond <execution-id> --deny -m "Please use a different approach"
```

### Deploy agent

```bash
agentspan agent deploy <module-or-file>
```

Pushes agent definition to the server.

## Credentials

### Store credential

```bash
# Simple form — logical key name equals storage name
agentspan credentials set KEY_NAME value

# Advanced form — custom storage name (useful when binding multiple logical keys to one secret)
agentspan credentials set --name STORE_NAME value
agentspan credentials bind LOGICAL_KEY STORE_NAME
```

Value is passed as a positional argument. Stored encrypted (AES-256-GCM) on the server. Key names are shown in `list` — values are never exposed.

### List credentials

```bash
agentspan credentials list
```

Shows credential names (not values).

## Configuration

### Configure server connection

```bash
agentspan configure --url <server-url> --auth-key <key> --auth-secret <secret>
```

Saves to `~/.agentspan/config.yaml`.

### Login

```bash
agentspan login
```

Interactive authentication.

## Diagnostics

### Doctor

```bash
agentspan doctor
```

Checks: CLI version, server connectivity, Java version, Python/SDK version, credentials access.

### Update CLI

```bash
agentspan update
```

Self-updates to the latest version from GitHub releases.
