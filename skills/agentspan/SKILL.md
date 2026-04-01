---
name: agentspan
description: "Build, run, monitor, and manage durable AI agents with AgentSpan. Use when the user wants to create agents, define tools, orchestrate multi-agent teams, handle human-in-the-loop approvals, stream events, or manage credentials. Uses the `agentspan` CLI or Python SDK. Requires AGENTSPAN_SERVER_URL."
allowed-tools: Bash(agentspan *), Bash(python3 *), Bash(pip install *), Bash(npm install *), Bash(chmod *), Bash(* --version), Bash(* --help), Bash(echo *), Read, Write, Edit, Grep, Glob
---

# AgentSpan — Build Durable AI Agents

AI agents that don't die when your process dies. Agents compile to server-side workflows, survive crashes, scale across machines, and pause for human approval.

## Rules

- **Always install and use the `agentspan` CLI proactively.** If missing, run `npm install -g @agentspan/agentspan`. Verify with `agentspan --version` and `agentspan doctor`. Do not just tell the user to install it — do it yourself.
- **Never hardcode credentials in code.** Always use `agentspan credentials set --name KEY` and reference via `credentials=["KEY"]` in Agent definitions.
- **Never use `python3 -c`** for any purpose. Write Python to files using the Write tool, then run them.
- **Server resolution:** `AGENTSPAN_SERVER_URL` env var or `agentspan configure` settings. Default local server: `http://localhost:6767`.
- **Always check `result.is_success`** before using `result.output` — especially in autonomous agent flows.
- **Agent names must be unique** — alphanumeric + underscore/hyphen, start with letter or underscore.
- **Tools need type hints and docstrings** — schema is auto-generated from them.
- **Use `result.output["result"]`** for text output, not `result.output` directly (it's a dict).
- **Deploy is idempotent** — safe to call on every startup.
- **Serve blocks forever** — triggering comes from outside (CLI, API, another process).

## Updating this skill

```bash
curl -sSL https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.sh | bash -s -- --all --upgrade
```

On Windows:
```powershell
irm https://raw.githubusercontent.com/agentspan/agentspan-skills/main/install.ps1 -OutFile install.ps1; .\install.ps1 -All -Upgrade
```

## First-time setup

Follow every step in order. Do not skip steps.

### Step 1 — Install the CLI

```bash
agentspan --version
```

If not installed:

```bash
npm --version
```

If npm is missing, install Node.js first (`brew install node` on macOS). Then:

```bash
npm install -g @agentspan/agentspan
```

Verify:

```bash
agentspan --version
agentspan doctor
```

**Fallback:** Only if CLI and npm are both unavailable, install the Python SDK directly:

```bash
pip install agentspan
```

### Step 2 — Choose a server

**Ask the user** whether they want:

- **Option A** — Start a local server (development/testing)
- **Option B** — Connect to an existing remote server

**Option A — Local server:**

```bash
agentspan server start
```

Verify: `agentspan server status`

**Option B — Remote server:**

```bash
agentspan configure --url https://your-server:8080/api --auth-key YOUR_KEY
```

### Step 3 — Test connectivity

```bash
agentspan doctor
agentspan agent list
```

If 401/403, ask user for credentials:

```bash
agentspan configure --url URL --auth-key KEY --auth-secret SECRET
```

### Step 4 — Install Python SDK

```bash
pip install agentspan
```

Setup is complete.

## 1) Creating agents

### Basic agent

```python
from agentspan.agents import Agent, AgentRuntime

agent = Agent(
    name="helper",
    model="openai/gpt-4o",
    instructions="You are a helpful assistant.",
)

with AgentRuntime() as rt:
    result = rt.run(agent, "What is quantum computing?")
    print(result.output["result"])
```

### Agent with all options

```python
Agent(
    name="my_agent",
    model="openai/gpt-4o",             # "provider/model" format
    instructions="You are a ...",       # System prompt (str, callable, or PromptTemplate)
    tools=[my_tool],                    # List of @tool functions
    max_turns=25,                       # Max LLM iterations
    timeout_seconds=0,                  # 0 = no timeout
    max_tokens=None,                    # Max output tokens per LLM call
    temperature=None,                   # LLM temperature
    output_type=MyPydanticModel,        # Structured output (Pydantic model)
    planner=False,                      # Enable planning-first behavior
    thinking_budget_tokens=None,        # Extended reasoning token budget
    credentials=["API_KEY"],            # Credentials resolved from server
    metadata={"team": "backend"},       # Custom metadata
)
```

### @agent decorator

```python
from agentspan.agents import agent

@agent(model="openai/gpt-4o", tools=[search])
def researcher():
    """You are a research assistant. Find and summarize information."""

# Use: rt.run(researcher, "Find info about quantum computing")
```

### Model formats

`"openai/gpt-4o"`, `"anthropic/claude-sonnet-4-6"`, `"google_gemini/gemini-2.5-flash"`, `"claude-code/opus"`, `"aws_bedrock/anthropic.claude-v2"`, `"azure_openai/gpt-4o"`, `"groq/llama-3-70b"`, `"ollama/llama3"`, `"deepseek/deepseek-chat"`, `"mistral/mistral-large"`, `"grok/grok-3"`

## 2) Tools

### @tool decorator

```python
from agentspan.agents import tool

@tool
def search(query: str) -> str:
    """Search the web for information."""
    return f"Results for: {query}"

@tool(approval_required=True, credentials=["API_KEY"])
def delete_file(path: str) -> str:
    """Delete a file. Requires human approval."""
    os.remove(path)
    return f"Deleted {path}"
```

Tool functions **must** have type hints and a docstring. Schema is auto-generated.

### ToolContext (dependency injection)

```python
from agentspan.agents import tool, ToolContext

@tool
def lookup(query: str, context: ToolContext) -> str:
    """Search with context."""
    exec_id = context.execution_id
    state = context.state          # Mutable dict shared across tool calls
    deps = context.dependencies    # From Agent(dependencies={...})
    return f"Found in execution {exec_id}"
```

### Server-side tools (no local worker needed)

```python
from agentspan.agents import http_tool, mcp_tool, search_tool

weather = http_tool(
    name="get_weather",
    description="Get weather for a city",
    url="https://api.weather.com/v1/current?city=${city}",
    credentials=["WEATHER_API_KEY"],
)

github = mcp_tool(
    server_url="https://mcp.github.com",
    tool_names=["create_issue", "list_repos"],
    credentials=["GITHUB_TOKEN"],
)

# Built-in tools: search_tool, index_tool
```

### Agent as tool

```python
from agentspan.agents import agent_tool

specialist = Agent(name="math_expert", model="openai/gpt-4o", instructions="Solve math problems.")

orchestrator = Agent(
    name="orchestrator",
    model="openai/gpt-4o",
    tools=[agent_tool(specialist, description="Call the math expert")],
)
```

## 3) Running agents

### Ephemeral (one-shot)

```python
with AgentRuntime() as rt:
    result = rt.run(agent, "prompt")                    # Sync
    result = await rt.run_async(agent, "prompt")        # Async

    result = rt.run(agent, "prompt",
        session_id="conv-123",                          # Multi-turn
        media=["https://example.com/image.png"],        # Multimodal
        timeout=60000,                                  # Timeout ms
        credentials=["MY_API_KEY"],                     # Runtime credentials
    )
```

### Streaming

```python
    stream = rt.stream(agent, "prompt")
    for event in stream:
        print(event.type, event.content)
    result = stream.get_result()
```

### Non-blocking

```python
    handle = rt.start(agent, "prompt")
    status = rt.get_status(handle.execution_id)
    handle.pause()
    handle.resume()
    handle.cancel("no longer needed")
```

### Production (deploy + serve)

```python
    rt.deploy(agent)     # Push definition to server (idempotent)
    rt.serve(agent)      # Start workers, poll for tasks (blocks forever)
```

Trigger from outside:

```bash
agentspan agent run --name helper "What is quantum computing?"
```

### CLI execution

```bash
# Run by name (agent must be deployed)
agentspan agent run --name helper "What is quantum computing?"

# Run from config file
agentspan agent run --config agent.yaml "prompt"

# Check status
agentspan agent status <execution-id>

# Stream events
agentspan agent stream <execution-id>
```

## 4) Multi-agent orchestration

### Sequential pipeline (>>)

```python
researcher = Agent(name="researcher", model="openai/gpt-4o", instructions="Research the topic.")
writer = Agent(name="writer", model="openai/gpt-4o", instructions="Write a summary.")

pipeline = researcher >> writer
result = rt.run(pipeline, "Quantum computing breakthroughs")
```

### Parallel

```python
Agent(
    name="analysis",
    model="openai/gpt-4o",
    agents=[pros_agent, cons_agent],
    strategy="parallel",
)
```

### Router

```python
Agent(
    name="team",
    model="openai/gpt-4o",
    agents=[billing, technical],
    strategy="router",
    router=router_agent,
)
```

### Swarm (peer-to-peer handoff)

```python
from agentspan.agents.handoff import OnTextMention

coder = Agent(name="coder", model="openai/gpt-4o", instructions="Code. Say HANDOFF_TO_QA when done.")
qa = Agent(name="qa", model="openai/gpt-4o", instructions="Test. Say HANDOFF_TO_CODER if bugs found.")

Agent(
    name="dev_team",
    model="openai/gpt-4o",
    agents=[coder, qa],
    strategy="swarm",
    handoffs=[
        OnTextMention(text="HANDOFF_TO_QA", target="qa"),
        OnTextMention(text="HANDOFF_TO_CODER", target="coder"),
    ],
)
```

### Scatter-gather (fan-out/fan-in)

```python
from agentspan.agents import scatter_gather

coordinator = scatter_gather(
    name="multi_search",
    worker=Agent(name="searcher", model="openai/gpt-4o-mini", instructions="Search and summarize."),
    timeout_seconds=300,
)
```

Strategies: `handoff`, `sequential`, `parallel`, `router`, `round_robin`, `random`, `swarm`, `manual`

## 5) Monitoring and managing

### List agents

```bash
agentspan agent list
```

### Get agent definition

```bash
agentspan agent get <name>
```

### Search executions

```bash
agentspan agent execution --status FAILED --since 1d
agentspan agent execution --status RUNNING --since 7d
agentspan agent execution --status COMPLETED
```

### Execution details

```bash
agentspan agent status <execution-id>
```

### Stream events (SSE)

```bash
agentspan agent stream <execution-id>
```

### Delete agent

```bash
agentspan agent delete <name>
```

## 6) Human-in-the-loop

Mark any tool with `approval_required=True` — execution pauses durably (days, not minutes):

```python
@tool(approval_required=True)
def deploy_to_prod(service: str) -> str:
    """Deploy service to production. Requires approval."""
    return f"Deployed {service}"

agent = Agent(name="deployer", model="openai/gpt-4o", tools=[deploy_to_prod])
```

When the agent calls this tool, execution pauses. Approve or reject from any machine:

```bash
# Approve
agentspan agent respond <execution-id> --approve

# Reject with reason
agentspan agent respond <execution-id> --reject --reason "Not ready"
```

Or via Python:

```python
handle = rt.start(agent, "Deploy the auth service")
# ... later ...
handle.approve()   # or handle.reject("reason")
```

## 7) Guardrails

```python
from agentspan.agents import RegexGuardrail, LLMGuardrail, Guardrail, GuardrailResult

# Regex: block emails in output
RegexGuardrail(
    name="no_emails",
    patterns=[r"[\w.+-]+@[\w-]+\.[\w.-]+"],
    message="Remove email addresses.",
    on_fail="retry",    # retry | raise | fix | human
    max_retries=3,
)

# LLM: policy-based check
LLMGuardrail(
    name="safety",
    model="openai/gpt-4o-mini",
    policy="Reject responses with medical advice.",
    on_fail="raise",
)

# Custom function
def no_ssn(content: str) -> GuardrailResult:
    if re.search(r"\b\d{3}-\d{2}-\d{4}\b", content):
        return GuardrailResult(passed=False, message="Redact SSNs.")
    return GuardrailResult(passed=True)

Guardrail(no_ssn, position="output", on_fail="retry", max_retries=3)
```

Failure modes: `retry` (auto-retry), `raise` (throw exception), `fix` (LLM auto-fix), `human` (escalate)

## 8) Memory and state

### Conversation memory (chat history)

```python
from agentspan.agents import ConversationMemory

agent = Agent(
    name="chatbot",
    model="openai/gpt-4o",
    memory=ConversationMemory(max_messages=50),
)
```

### Semantic memory (long-term, searchable)

```python
from agentspan.agents import SemanticMemory

memory = SemanticMemory()
memory.add("User prefers Python over JavaScript")
memory.add("User works at Acme Corp")
results = memory.search("What language does the user prefer?")
```

## 9) Credentials management

Credentials are always resolved from the server. No env var fallback. Missing credentials cause `FAILED_WITH_TERMINAL_ERROR`.

```bash
# Store credentials on server
agentspan credentials set --name GITHUB_TOKEN
agentspan credentials set --name OPENAI_API_KEY

# List stored credentials
agentspan credentials list
```

```python
Agent(
    name="github_agent",
    model="openai/gpt-4o",
    credentials=["GITHUB_TOKEN"],
    tools=[my_github_tool],
)
```

## 10) Advanced features

### Structured output

```python
from pydantic import BaseModel

class Analysis(BaseModel):
    sentiment: str
    confidence: float
    summary: str

agent = Agent(name="analyzer", model="openai/gpt-4o", output_type=Analysis)
result = rt.run(agent, "Analyze this text...")
analysis: Analysis = result.output  # Fully typed
```

### Termination conditions

```python
from agentspan.agents import TextMentionTermination, MaxMessageTermination

Agent(
    name="worker",
    model="openai/gpt-4o",
    instructions="Say DONE when finished.",
    termination=TextMentionTermination("DONE"),
    # Composable: termination=TextMentionTermination("DONE") | MaxMessageTermination(10),
)
```

### Gates (conditional pipelines)

```python
from agentspan.agents.gate import TextGate

checker = Agent(name="checker", model="openai/gpt-4o",
    instructions="Output NO_ISSUES if everything is fine.",
    gate=TextGate("NO_ISSUES"),
)
fixer = Agent(name="fixer", model="openai/gpt-4o", instructions="Fix the issue.")

pipeline = checker >> fixer  # fixer only runs if checker finds issues
```

### Callbacks

```python
from agentspan.agents import CallbackHandler

class MyCallbacks(CallbackHandler):
    def on_agent_start(self, **kwargs): pass
    def on_agent_end(self, **kwargs): pass
    def on_model_start(self, **kwargs): pass
    def on_model_end(self, **kwargs): pass

Agent(name="agent", model="openai/gpt-4o", callbacks=[MyCallbacks()])
```

### Claude Code agents

```python
from agentspan.agents import Agent, ClaudeCode

reviewer = Agent(
    name="reviewer",
    model="claude-code/sonnet",
    instructions="Review code for quality.",
    tools=["Read", "Glob", "Grep"],     # Built-in Claude tools (strings only)
    max_turns=10,
)

# With config
reviewer = Agent(
    name="reviewer",
    model=ClaudeCode("opus", permission_mode=ClaudeCode.PermissionMode.ACCEPT_EDITS),
    instructions="Review code.",
    tools=["Read", "Edit", "Bash"],
)
```

### Code execution

```python
Agent(
    name="data_scientist",
    model="openai/gpt-4o",
    instructions="Write and run Python code.",
    local_code_execution=True,
    allowed_languages=["python"],
)
```

### Framework integration

```python
# LangGraph
from langgraph.prebuilt import create_react_agent
from langchain_openai import ChatOpenAI

graph = create_react_agent(ChatOpenAI(model="gpt-4o"), tools=[my_tool])
with AgentRuntime() as rt:
    result = rt.run(graph, "What is 15 * 7?")

# OpenAI Agents SDK
from agents import Agent as OpenAIAgent

agent = OpenAIAgent(name="helper", instructions="...", model="gpt-4o")
with AgentRuntime() as rt:
    result = rt.run(agent, "Hello")
```

## AgentResult reference

```python
result = rt.run(agent, "prompt")

result.output            # Dict: {"result": "..."} or structured output
result.output["result"]  # The text output (string)
result.status            # "COMPLETED", "FAILED", "TERMINATED", "TIMED_OUT"
result.execution_id      # Execution ID
result.error             # Error message if failed, else None
result.token_usage       # {"input_tokens": N, "output_tokens": N}
result.finish_reason     # "stop", "length", "error", "cancelled", "timeout", "guardrail"
result.is_success        # True if COMPLETED
result.is_failed         # True if FAILED/TERMINATED
result.sub_results       # List of sub-agent results (multi-agent)
result.print_result()    # Pretty-print output
```

## Output formatting

- Present agent results as structured summaries: execution_id, status, output, token_usage.
- For executions, show a table with execution_id, agent_name, status, start_time.
- On failures, include the error message, failed task, and finish_reason.
- Never echo credentials or secrets in output.

## Troubleshooting

- **CLI not found**: Install via `npm install -g @agentspan/agentspan`, or use `pip install agentspan` for SDK-only.
- **Connection refused**: Verify `AGENTSPAN_SERVER_URL` is correct and server is running. Try `agentspan doctor`.
- **401 Unauthorized**: Run `agentspan configure` with correct credentials.
- **Missing credentials**: Store with `agentspan credentials set --name KEY`. Agent gets `FAILED_WITH_TERMINAL_ERROR` if credential is missing.
- **Tool schema errors**: Ensure tool functions have type hints and docstrings.
- **Agent name collision**: Agent names must be unique. Check with `agentspan agent list`.
- **Docs**: https://github.com/agentspan-ai/agentspan
