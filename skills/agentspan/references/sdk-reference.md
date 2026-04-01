# AgentSpan Python SDK Reference

## Installation

```bash
pip install agentspan
```

## Agent

```python
from agentspan.agents import Agent

Agent(
    name: str,                          # Required. Unique identifier.
    model: str,                         # Required. "provider/model" format.
    instructions: str | Callable,       # System prompt or callable returning prompt.
    tools: list = [],                   # @tool functions, http_tool, mcp_tool, search_tool, etc.
    agents: list[Agent] = [],           # Sub-agents for multi-agent orchestration
    strategy: str = "handoff",          # handoff|sequential|parallel|router|round_robin|random|swarm|manual
    router: Agent = None,               # Router agent (for strategy="router")
    handoffs: list = [],                # HandoffCondition list (for strategy="swarm")
    max_turns: int = 25,                # Max LLM iterations
    timeout_seconds: int = 0,           # 0 = no timeout
    max_tokens: int = None,             # Max output tokens per LLM call
    temperature: float = None,          # LLM temperature
    output_type: type[BaseModel] = None,# Structured output (Pydantic model)
    planner: bool = False,              # Planning-first behavior
    thinking_budget_tokens: int = None, # Extended reasoning budget
    credentials: list[str] = [],        # Credential names resolved from server
    metadata: dict = {},                # Custom metadata
    memory: Memory = None,              # ConversationMemory or SemanticMemory
    guardrails: list[Guardrail] = [],   # Input/output guardrails
    termination: TerminationCondition = None,  # When to stop
    gate: Gate = None,                  # Conditional pipeline gate
    callbacks: list[CallbackHandler] = [],     # Lifecycle hooks
    local_code_execution: bool = False, # Enable code execution
    allowed_languages: list[str] = [],  # For code execution
    cli_commands: bool = False,         # Enable CLI tool
    cli_allowed_commands: list[str] = [],      # Allowed CLI commands
    dependencies: dict = {},            # Injected via ToolContext
)
```

## AgentRuntime

```python
from agentspan.agents import AgentRuntime, AgentConfig

# Default (reads AGENTSPAN_SERVER_URL from env)
rt = AgentRuntime()

# Explicit config
config = AgentConfig(server_url="http://localhost:6767", api_key="...")
rt = AgentRuntime(config=config)

# Context manager
with AgentRuntime() as rt:
    # Ephemeral
    result = rt.run(agent, "prompt")
    result = await rt.run_async(agent, "prompt")

    # With options
    result = rt.run(agent, "prompt",
        session_id="conv-123",
        media=["https://example.com/image.png"],
        timeout=60000,
        credentials=["KEY"],
    )

    # Streaming
    stream = rt.stream(agent, "prompt")
    stream = await rt.stream_async(agent, "prompt")

    # Non-blocking
    handle = rt.start(agent, "prompt")

    # By name (trigger deployed agent)
    result = rt.run("agent_name", "prompt")

    # Production
    rt.deploy(agent)     # Push definition (idempotent)
    rt.serve(agent)      # Start workers (blocks forever)

    # Status
    status = rt.get_status(execution_id)
```

## AgentResult

```python
result.output            # Dict: {"result": "..."} or Pydantic model
result.output["result"]  # Text output string
result.status            # "COMPLETED" | "FAILED" | "TERMINATED" | "TIMED_OUT"
result.execution_id      # Execution ID
result.error             # Error message or None
result.token_usage       # {"input_tokens": N, "output_tokens": N}
result.finish_reason     # "stop" | "length" | "error" | "cancelled" | "timeout" | "guardrail"
result.is_success        # True if COMPLETED
result.is_failed         # True if FAILED/TERMINATED
result.sub_results       # List[AgentResult] for multi-agent
result.print_result()    # Pretty-print
```

## AgentHandle

```python
handle = rt.start(agent, "prompt")

handle.execution_id      # Execution ID
handle.pause()           # Pause execution
handle.resume()          # Resume execution
handle.cancel(reason)    # Cancel with reason
handle.approve()         # Approve HITL task
handle.reject(reason)    # Reject HITL task
handle.get_status()      # AgentStatus
```

## Tools

### @tool decorator

```python
from agentspan.agents import tool

@tool
def my_func(param: str) -> str:
    """Description used as tool schema."""
    return result

@tool(approval_required=True, credentials=["KEY"])
def dangerous_func(param: str) -> str:
    """Requires human approval and a credential."""
    return result
```

### ToolContext

```python
from agentspan.agents import tool, ToolContext

@tool
def my_func(param: str, context: ToolContext) -> str:
    """Tool with context injection."""
    context.execution_id     # Current execution ID
    context.session_id       # Session ID
    context.state            # Mutable dict shared across calls
    context.dependencies     # From Agent(dependencies={...})
    return result
```

### http_tool (server-side HTTP)

```python
from agentspan.agents import http_tool

tool = http_tool(
    name="api_call",
    description="Call an API",
    url="https://api.example.com/data?q=${query}",
    method="GET",                    # GET|POST|PUT|DELETE
    headers={"Auth": "Bearer ${token}"},
    body=None,                       # For POST/PUT
    credentials=["API_KEY"],
)
```

### mcp_tool (MCP server auto-discovery)

```python
from agentspan.agents import mcp_tool

tools = mcp_tool(
    server_url="https://mcp.example.com",
    tool_names=["tool1", "tool2"],   # Specific tools, or omit for all
    credentials=["MCP_TOKEN"],
)
```

### Built-in tools

```python
from agentspan.agents import search_tool, index_tool

# Pre-built server-side tools for common operations
```

### agent_tool (agent as tool)

```python
from agentspan.agents import agent_tool

tool = agent_tool(agent, description="Delegate to this agent")
```

## Guardrails

```python
from agentspan.agents import Guardrail, RegexGuardrail, LLMGuardrail, GuardrailResult

# Regex
RegexGuardrail(name, patterns: list[str], message: str, on_fail: str, max_retries: int = 3)

# LLM
LLMGuardrail(name, model: str, policy: str, on_fail: str)

# Custom function
def check(content: str) -> GuardrailResult:
    return GuardrailResult(passed=True)  # or passed=False, message="..."

Guardrail(check, position="output", on_fail="retry", max_retries=3)
```

`on_fail`: `"retry"` | `"raise"` | `"fix"` | `"human"`

## Memory

```python
from agentspan.agents import ConversationMemory, SemanticMemory

# Chat history (windowed)
ConversationMemory(max_messages=50)

# Long-term searchable
memory = SemanticMemory()
memory.add("fact")
results = memory.search("query")
```

## Termination Conditions

```python
from agentspan.agents import TextMentionTermination, MaxMessageTermination

TextMentionTermination("DONE")
MaxMessageTermination(10)

# Composable
condition = TextMentionTermination("DONE") | MaxMessageTermination(10)   # OR
condition = TextMentionTermination("DONE") & MaxMessageTermination(10)   # AND
```

## Handoffs

```python
from agentspan.agents.handoff import OnTextMention, OnToolResult, OnCondition

OnTextMention(text="HANDOFF_TO_X", target="agent_name")
OnToolResult(tool_name="search", target="analyst")
OnCondition(condition=lambda result: "error" in result, target="debugger")
```

## Gates

```python
from agentspan.agents.gate import TextGate

TextGate("NO_ISSUES")  # Stops pipeline if text found in output
```

## Callbacks

```python
from agentspan.agents import CallbackHandler

class MyCallbacks(CallbackHandler):
    def on_agent_start(self, **kwargs): pass
    def on_agent_end(self, **kwargs): pass
    def on_model_start(self, **kwargs): pass
    def on_model_end(self, **kwargs): pass
    def on_tool_start(self, **kwargs): pass
    def on_tool_end(self, **kwargs): pass
```

## Supported LLM Providers

| Provider | Env Var | Model Format |
|----------|---------|--------------|
| OpenAI | `OPENAI_API_KEY` | `openai/gpt-4o` |
| Anthropic | `ANTHROPIC_API_KEY` | `anthropic/claude-sonnet-4-6` |
| Google Gemini | `GEMINI_API_KEY` | `google_gemini/gemini-2.5-flash` |
| Azure OpenAI | `AZURE_OPENAI_API_KEY` | `azure_openai/gpt-4o` |
| AWS Bedrock | `AWS_ACCESS_KEY_ID` | `aws_bedrock/anthropic.claude-v2` |
| Mistral | `MISTRAL_API_KEY` | `mistral/mistral-large` |
| Cohere | `COHERE_API_KEY` | `cohere/command-r-plus` |
| Groq | `GROQ_API_KEY` | `groq/llama-3-70b` |
| DeepSeek | `DEEPSEEK_API_KEY` | `deepseek/deepseek-chat` |
| Grok/xAI | `XAI_API_KEY` | `grok/grok-3` |
| Ollama | `OLLAMA_HOST` | `ollama/llama3` |
| Claude Code | — | `claude-code/opus` |
