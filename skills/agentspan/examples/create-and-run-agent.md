# Example: Create and run an agent

**User prompt:** "Create an agent that searches the web and summarizes results, then run it"

## Agent response

### Step 1 — Check prerequisites

```bash
agentspan --version
agentspan doctor
```

Server is running on localhost:6767. Python SDK installed.

### Step 2 — Write the agent

```python
# search_agent.py
from agentspan.agents import Agent, AgentRuntime, tool

@tool
def web_search(query: str) -> str:
    """Search the web and return results."""
    import urllib.request, json
    url = f"https://api.duckduckgo.com/?q={query}&format=json"
    with urllib.request.urlopen(url) as resp:
        data = json.loads(resp.read())
    return data.get("AbstractText", "No results found.")

agent = Agent(
    name="search_summarizer",
    model="openai/gpt-4o",
    instructions="Search the web for the user's query and provide a clear, concise summary of what you find.",
    tools=[web_search],
    max_turns=5,
)

if __name__ == "__main__":
    with AgentRuntime() as rt:
        result = rt.run(agent, "What are the latest breakthroughs in quantum computing?")
        if result.is_success:
            result.print_result()
        else:
            print(f"Failed: {result.error}")
```

### Step 3 — Run it

```bash
python3 search_agent.py
```

### Step 4 — Check execution

```bash
agentspan agent execution --status COMPLETED --since 1h
```

### Step 5 — Present result

> **Agent: search_summarizer** | Status: COMPLETED
>
> Recent quantum computing breakthroughs include...
> - Google's Willow chip achieving quantum error correction below threshold
> - IBM's 1000+ qubit Condor processor
> - Microsoft's topological qubit advances
>
> Token usage: 1,247 input / 342 output
