# agentspan-skills — Claude Code context

## What this repo is

Skills for AI coding agents to build with the agentspan Python SDK. The skill files in `skills/agentspan/` are installed into agent contexts (Claude Code, Codex, Cursor, etc.) via the install script or Claude Code plugin.

The canonical agentspan SDK: github.com/agentspan-ai/agentspan

---

## Key commands

```bash
# Install all skills locally (for testing)
curl -sSL https://raw.githubusercontent.com/agentspan-ai/agentspan-skills/main/install.sh | bash -s -- --all

# Claude Code plugin
/plugin marketplace add agentspan-ai/agentspan-skills
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
from agentspan.agents import image_tool, audio_tool, video_tool, pdf_tool, api_tool, human_tool
from agentspan.agents.testing import mock_run, MockEvent, expect
```

### Agent defaults
- `max_turns=25` (not 20)
- `timeout_seconds=0` (not 3600; 0 = no timeout)
- Default multi-agent strategy: `HANDOFF` (not SEQUENTIAL)

### AgentResult fields
- `result.output` → a `dict` `{'result': str, 'finishReason': str}` for plain text agents; a Pydantic model instance when `output_type=` is set on the agent
- `result.output['result']` → the text output (only when no `output_type` is set)
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

### configure() server URL
`configure(server_url=...)` requires the URL to include `/api`:
```python
configure(server_url="http://localhost:6767/api")   # correct
configure(server_url="http://localhost:6767")        # WRONG — builds bad URLs
```

### Additional built-in tools (server-side, no worker needed)
Beyond `search_tool` and `index_tool`, these also exist:
- `image_tool(name, description, llm_provider, model, ...)` — image generation
- `audio_tool(name, description, llm_provider, model, ...)` — audio generation
- `video_tool(name, description, llm_provider, model, ...)` — video generation
- `pdf_tool(name, description, ...)` — PDF generation from markdown
- `api_tool(url, name, ...)` — wraps an OpenAPI/REST endpoint
- `human_tool(name, description, ...)` — human-in-the-loop tool

### Things that do NOT exist
- `handle.wait()` — use `handle.stream().get_result()`
- `handle.select_agent()` — doesn't exist
- `runtime.register_workers()` — use `runtime.serve(agent, blocking=False)`
- `result.workflow_id` — use `result.execution_id`
- `handle.workflow_id` — use `handle.execution_id`
- `memory.store()` as a callable — `memory.add()` is the correct method
- `configure(providers={...})` — providers param doesn't exist
- `async with stream_async(...)` — not supported; use `s = await stream_async(...)` then `async for event in s`
- `parallel(a, b)` / `handoff([a, b])` — not functions
- `agentspan.integrations.*` — no such module

### Install note
`pip install agentspan` installs all dependencies including `conductor-python>=1.3.9` from PyPI.
