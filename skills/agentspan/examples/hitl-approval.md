# Example: Human-in-the-loop approval

**User prompt:** "Create an agent that deletes files but requires my approval first"

## Agent response

### Step 1 — Write the agent

```python
# file_manager.py
import os
from agentspan.agents import Agent, AgentRuntime, tool

@tool(approval_required=True)
def delete_file(path: str) -> str:
    """Delete a file at the given path. Requires human approval before executing."""
    if not os.path.exists(path):
        return f"File not found: {path}"
    os.remove(path)
    return f"Deleted: {path}"

@tool
def list_files(directory: str) -> str:
    """List files in a directory."""
    files = os.listdir(directory)
    return "\n".join(files)

agent = Agent(
    name="file_manager",
    model="openai/gpt-4o",
    instructions="Help the user manage files. Always confirm which files to delete before calling delete_file.",
    tools=[list_files, delete_file],
)

if __name__ == "__main__":
    with AgentRuntime() as rt:
        handle = rt.start(agent, "Delete all .tmp files in /tmp/cleanup/")
        print(f"Execution started: {handle.workflow_id}")
        print("Waiting for approval... Run:")
        print(f"  agentspan agent respond {handle.workflow_id} --approve")
```

### Step 2 — Run it

```bash
python3 file_manager.py
```

Output:

```
Execution started: abc-123-def-456
Waiting for approval... Run:
  agentspan agent respond abc-123-def-456 --approve
```

### Step 3 — Check status (execution is paused)

```bash
agentspan agent status abc-123-def-456
```

```
Status: RUNNING (paused at HITL task)
Current task: delete_file (awaiting approval)
Pending action: delete /tmp/cleanup/cache.tmp
```

### Step 4 — Approve

```bash
agentspan agent respond abc-123-def-456 --approve
```

### Step 5 — Verify completion

```bash
agentspan agent status abc-123-def-456
```

> **Agent: file_manager** | Status: COMPLETED
>
> Deleted 3 files:
> - /tmp/cleanup/cache.tmp
> - /tmp/cleanup/session.tmp
> - /tmp/cleanup/old_data.tmp
