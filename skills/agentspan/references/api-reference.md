# AgentSpan REST API Reference

Base URL: `{AGENTSPAN_SERVER_URL}` (default: `http://localhost:8080/api`)

## Authentication

For authenticated servers, include a Bearer token:

```
Authorization: Bearer <token>
```

Obtain a token using key/secret:

```
POST /api/token
{"keyId": "...", "keySecret": "..."}
→ {"token": "eyJ..."}
```

## Agent endpoints

### Start agent

```
POST /api/agent/start
Content-Type: application/json

{
  "name": "my_agent",
  "model": "openai/gpt-4o",
  "instructions": "You are a helpful assistant.",
  "tools": [...],
  "input": {"prompt": "What is quantum computing?"}
}

→ {"workflowId": "abc-123-def"}
```

Compiles, registers, and starts the agent in one call.

### Compile agent (inspect only)

```
POST /api/agent/compile
Content-Type: application/json

{...agent config...}

→ {workflow definition JSON}
```

### List agents

```
GET /api/agent/list

→ [{"name": "agent1", "version": 1, "description": "..."}, ...]
```

### Get agent definition

```
GET /api/agent/get/{name}

→ {full workflow definition}
```

### Delete agent

```
DELETE /api/agent/delete/{name}

→ 200 OK
```

## Execution endpoints

### Search executions

```
GET /api/agent/executions?status=RUNNING&size=20&name=my_agent

→ {
    "results": [
      {"workflowId": "abc-123", "workflowName": "my_agent", "status": "RUNNING", "startTime": 1234567890}
    ],
    "totalHits": 5
  }
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | RUNNING, COMPLETED, FAILED, TERMINATED, TIMED_OUT, PAUSED |
| `size` | int | Max results (default 10) |
| `name` | string | Filter by agent name |
| `startTime` | long | Filter by start time (epoch ms) |

### Get execution details

```
GET /api/agent/executions/{workflowId}

→ {
    "workflowId": "abc-123",
    "status": "COMPLETED",
    "input": {...},
    "output": {...},
    "startTime": 1234567890,
    "endTime": 1234567899,
    "tasks": [...]
  }
```

### Stream events (SSE)

```
GET /api/agent/stream/{workflowId}
Accept: text/event-stream

→ data: {"type": "tool_call", "content": "Calling search..."}
→ data: {"type": "thinking", "content": "Analyzing results..."}
→ data: {"type": "done", "content": "Task completed"}
```

Event types: `tool_call`, `thinking`, `guardrail_pass`, `guardrail_fail`, `done`, `error`

### Respond to HITL task

```
POST /api/agent/{workflowId}/respond
Content-Type: application/json

{"action": "approve"}
// or
{"action": "reject", "reason": "Not ready"}

→ 200 OK
```

### Get execution status

```
GET /api/agent/{workflowId}/status

→ {"status": "RUNNING", "currentTask": "search_ref"}
```

## HTTP response codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad request (invalid config) |
| 401 | Unauthorized (missing/invalid token) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Agent or execution not found |
| 409 | Conflict (agent name already exists on create) |
| 500 | Server error |
