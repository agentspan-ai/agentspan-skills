# Example: Monitor and debug failed executions

**User prompt:** "Show me all failed agent executions from today and help me debug them"

## Agent response

### Step 1 — Search failed executions

```bash
agentspan agent execution --status FAILED --since 1d
```

```
EXECUTION ID                           AGENT NAME        STATUS   START TIME
a1b2c3d4-e5f6-7890-abcd-ef1234567890   research_writer   FAILED   2026-03-29 14:23:01
b2c3d4e5-f6a7-8901-bcde-f12345678901   data_pipeline     FAILED   2026-03-29 16:45:22
c3d4e5f6-a7b8-9012-cdef-123456789012   github_agent      FAILED   2026-03-29 18:12:45
```

### Step 2 — Inspect each failure

```bash
agentspan agent status a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

```
Agent: research_writer
Status: FAILED
Error: FAILED_WITH_TERMINAL_ERROR
Failed task: web_search
Reason: Missing credential: SEARCH_API_KEY
```

```bash
agentspan agent status b2c3d4e5-f6a7-8901-bcde-f12345678901
```

```
Agent: data_pipeline
Status: FAILED
Failed task: analyze_data (attempt 3/3)
Reason: TimeoutError - LLM call exceeded 30s timeout
```

```bash
agentspan agent status c3d4e5f6-a7b8-9012-cdef-123456789012
```

```
Agent: github_agent
Status: FAILED
Failed task: create_issue
Reason: 401 Unauthorized - GITHUB_TOKEN expired
```

### Step 3 — Diagnose and present findings

| Agent | Failed Task | Root Cause | Fix |
|-------|-------------|-----------|-----|
| research_writer | web_search | Missing credential `SEARCH_API_KEY` | `agentspan credentials set SEARCH_API_KEY <value>` |
| data_pipeline | analyze_data | LLM timeout (30s) | Increase `timeout_seconds` or use a faster model |
| github_agent | create_issue | Expired `GITHUB_TOKEN` | Update: `agentspan credentials set GITHUB_TOKEN <new-token>` |

### Step 4 — Fix and retry

For the credential issues:

```bash
agentspan credentials set SEARCH_API_KEY <your-key>
agentspan credentials set GITHUB_TOKEN <new-token>
```

Then re-run the agents:

```bash
agentspan agent run --name research_writer "Original prompt here"
agentspan agent run --name github_agent "Original prompt here"
```

For the timeout issue, update the agent definition to increase the timeout:

```python
agent = Agent(
    name="data_pipeline",
    model="openai/gpt-4o",
    timeout_seconds=120,  # Increased from 30
    ...
)
```
