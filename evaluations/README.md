# AgentSpan Skills Evaluations

Automated evaluation suite for testing the AgentSpan skill across LLM providers.

## Running evaluations

### Automated (recommended)

```bash
# Default: Claude Sonnet as agent and judge
python3 scripts/run_evals.py

# Specific model
python3 scripts/run_evals.py --model gpt-4o

# Verbose output
python3 scripts/run_evals.py --verbose

# JSON report
python3 scripts/run_evals.py --json --output results.json
```

### Supported providers

| Provider | Model prefix | Env var |
|----------|-------------|---------|
| Anthropic | `claude-*` | `ANTHROPIC_API_KEY` |
| OpenAI | `gpt-*`, `o1-*` | `OPENAI_API_KEY` |
| Google | `gemini-*` | `GEMINI_API_KEY` |

### Manual testing

1. Pick an eval JSON from this directory
2. Use the `query` as your prompt to the AI agent
3. Check if the agent's response matches `expected_behavior` and `success_criteria`

## Eval scenarios

| Eval | Tests |
|------|-------|
| `install-and-connect` | First-time CLI install, server start, doctor check |
| `create-and-run-agent` | Write a Python agent with tools, run it, check output |
| `multi-agent-team` | Sequential pipeline with >> operator |
| `hitl-approval` | approval_required tool, respond --approve |
| `monitor-executions` | Search and inspect executions by status/time |
| `stream-events` | SSE event streaming from running agent |
| `manage-credentials` | Store credentials, use in agent |
| `write-agent-code` | Scaffold agent code following SDK patterns |
| `visualize-agent` | Generate Mermaid diagram of agent workflow |
| `fallback-no-cli` | Use Python SDK when CLI unavailable |

## Writing new evaluations

Each eval JSON must have:

- `name`: Unique identifier
- `description`: What the eval tests
- `query`: The user prompt
- `expected_behavior`: Ordered list of steps the agent should take
- `success_criteria`: Pass/fail conditions
