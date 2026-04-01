# agentspan-skills — Claude Code context

## What this repo is

Skills for AI coding agents to build with the agentspan Python SDK. The skill files in `skills/agentspan/` are installed into agent contexts (Claude Code, Codex, Cursor, etc.) via the install script or Claude Code plugin.

The canonical agentspan SDK: github.com/agentspan-ai/agentspan

---

## Key commands

```bash
# Install all skills locally (for testing)
curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh | bash -s -- --all

# Claude Code plugin
/plugin marketplace add agentspan/agentspan-skills
/plugin install agentspan@agentspan-skills
```

---

## Repo layout

```
skills/agentspan/
  SKILL.md                    Core skill (main entry point for agent contexts)
  references/sdk-reference.md Python SDK API reference
  references/cli-reference.md CLI command reference
  references/api-reference.md REST API reference
  examples/                   Task-specific examples
  scripts/agentspan_api.py    Stdlib-only REST fallback
install.sh / install.ps1      Shell installers
.claude-plugin/               Claude Code plugin manifest
evaluations/                  Eval test cases
```

---

## Critical: agentspan API accuracy (v0.1.0 — verified against source)

**Every code example in every skill file must match the actual agentspan Python API.**

### Server port
Default local server: `http://localhost:6767` (NOT 8080)

### execution_id (NOT workflow_id)
- `result.execution_id` — NOT `result.workflow_id`
- `handle.execution_id` — NOT `handle.workflow_id`
- `context.execution_id` in ToolContext — NOT `context.workflow_id`
- The REST API uses `workflowId` at the wire level — that stays in api-reference.md

### Correct imports
```python
from agentspan.agents import Agent, tool, run, start, stream, configure, AgentRuntime, AgentHandle
from agentspan.agents import run_async, start_async, stream_async, shutdown, plan
from agentspan.agents import Strategy, Status, FinishReason, TokenUsage
from agentspan.agents import TextMentionTermination, MaxMessageTermination, StopMessageTermination, TokenUsageTermination
from agentspan.agents import CallbackHandler, ConversationMemory, SemanticMemory
from agentspan.agents import http_tool, mcp_tool, agent_tool, search_tool, index_tool
from agentspan.agents.testing import mock_run, MockEvent, expect
```

### Agent defaults
- `max_turns=25` (not 20)
- `timeout_seconds=0` (not 3600; 0 = no timeout)
- Default multi-agent strategy: `HANDOFF` (not SEQUENTIAL)

### AgentResult fields
- `result.output` → always a `dict`: `{'result': str, 'finishReason': str}`
- `result.output['result']` → the text output
- `result.execution_id` → str or None (NOT `workflow_id`)
- `result.token_usage` → only populated via `AgentRuntime` context manager; None via module-level `run()`

### AgentHandle
- `handle.execution_id` (NOT `workflow_id`)
- `handle.stream().get_result()` → wait for result (NOT `handle.wait()`)

### SemanticMemory
- Constructor: `SemanticMemory(store=None, max_results=5, session_id=None)`
- NO `namespace=` or `embedding_model=` params
- `memory.add(content)` — NOT `memory.store()`
- `memory.search(query)` → `List[str]`

### Guardrail
- `Guardrail(func=my_fn, ...)` — `func=` NOT `fn=`
- `RegexGuardrail` has no `flags=` param

### Things that do NOT exist
- `image_tool`, `audio_tool`, `video_tool`, `pdf_tool` — only `search_tool` and `index_tool`
- `handle.wait()` — use `handle.stream().get_result()`
- `handle.select_agent()` — doesn't exist
- `runtime.register_workers()` — use `runtime.serve(agent, blocking=False)`
- `result.workflow_id` — use `result.execution_id`
- `handle.workflow_id` — use `handle.execution_id`
- `memory.store()` — use `memory.add()`
- `configure(providers={...})` — providers param doesn't exist
- `async with stream_async(...)` — not supported; use `s = await stream_async(...)` then `async for event in s`
- `parallel(a, b)` / `handoff([a, b])` — not functions
- `agentspan.integrations.*` — no such module

### Install note
`conductor-python>=1.3.6` is required but not on PyPI yet. Dev install:
```bash
pip install "conductor-python @ git+https://github.com/conductor-oss/python-sdk.git"
pip install agentspan --no-deps
```
