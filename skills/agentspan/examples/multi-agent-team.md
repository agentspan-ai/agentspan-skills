# Example: Multi-agent research team

**User prompt:** "Create a research team with a researcher and writer that work in sequence"

## Agent response

### Step 1 — Write the team

```python
# research_team.py
from agentspan.agents import Agent, AgentRuntime

researcher = Agent(
    name="researcher",
    model="openai/gpt-4o",
    instructions="Research the given topic thoroughly. Provide detailed findings with sources.",
    max_turns=10,
)

writer = Agent(
    name="writer",
    model="openai/gpt-4o",
    instructions="Take the research findings and write a clear, well-structured summary article.",
    max_turns=5,
)

# Sequential pipeline: researcher runs first, output feeds into writer
pipeline = researcher >> writer

if __name__ == "__main__":
    with AgentRuntime() as rt:
        result = rt.run(pipeline, "The impact of AI on healthcare in 2026")

        if result.is_success:
            result.print_result()
            # Check individual agent results
            for i, sub in enumerate(result.sub_results):
                print(f"\n--- Agent {i+1}: {sub.status} ---")
        else:
            print(f"Failed: {result.error}")
```

### Step 2 — Run

```bash
python3 research_team.py
```

### Step 3 — Monitor execution

```bash
agentspan agent execution --status RUNNING --since 1h
agentspan agent stream <execution-id>
```

Events stream in real-time:

```
[tool_call] researcher: Searching for AI healthcare breakthroughs...
[thinking] researcher: Analyzing findings from 5 sources...
[done] researcher: Research complete
[thinking] writer: Organizing findings into article structure...
[done] writer: Article complete
```

### Step 4 — Present results

> **Pipeline: researcher >> writer** | Status: COMPLETED
>
> **Researcher output:** Found 12 key developments in AI healthcare...
>
> **Writer output:**
> # AI's Impact on Healthcare in 2026
> The healthcare industry has seen transformative changes...
>
> Token usage: 3,421 input / 1,856 output (total across both agents)
