#!/usr/bin/env python3
"""AgentSpan Skills evaluation runner.

Runs evaluation scenarios against LLM providers and scores results.

Usage:
    python3 scripts/run_evals.py
    python3 scripts/run_evals.py --model gpt-4o --verbose
    python3 scripts/run_evals.py --json --output results.json
"""

import argparse
import json
import os
import sys
import glob
import urllib.request
import urllib.error

PROVIDERS = {
    "anthropic": {
        "url": "https://api.anthropic.com/v1/messages",
        "env": "ANTHROPIC_API_KEY",
        "prefixes": ["claude-"],
        "default_model": "claude-sonnet-4-20250514",
    },
    "openai": {
        "url": "https://api.openai.com/v1/chat/completions",
        "env": "OPENAI_API_KEY",
        "prefixes": ["gpt-", "o1-", "o3-"],
        "default_model": "gpt-4o",
    },
    "gemini": {
        "url": "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        "env": "GEMINI_API_KEY",
        "prefixes": ["gemini-"],
        "default_model": "gemini-2.5-flash",
    },
}

DEFAULT_AGENT_MODEL = "claude-sonnet-4-20250514"
DEFAULT_JUDGE_MODEL = "claude-sonnet-4-20250514"


def detect_provider(model: str) -> str:
    for name, config in PROVIDERS.items():
        for prefix in config["prefixes"]:
            if model.startswith(prefix):
                return name
    raise ValueError(f"Cannot detect provider for model: {model}")


def get_api_key(provider: str) -> str:
    env = PROVIDERS[provider]["env"]
    key = os.environ.get(env)
    if not key:
        print(f"Error: {env} not set", file=sys.stderr)
        sys.exit(1)
    return key


def call_anthropic(model: str, api_key: str, system: str, user: str) -> str:
    data = json.dumps({
        "model": model,
        "max_tokens": 4096,
        "system": system,
        "messages": [{"role": "user", "content": user}],
    }).encode()
    req = urllib.request.Request(
        PROVIDERS["anthropic"]["url"],
        data=data,
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read())
    return result["content"][0]["text"]


def call_openai(model: str, api_key: str, system: str, user: str) -> str:
    data = json.dumps({
        "model": model,
        "max_tokens": 4096,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }).encode()
    req = urllib.request.Request(
        PROVIDERS["openai"]["url"],
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read())
    return result["choices"][0]["message"]["content"]


def call_gemini(model: str, api_key: str, system: str, user: str) -> str:
    url = PROVIDERS["gemini"]["url"].format(model=model) + f"?key={api_key}"
    data = json.dumps({
        "system_instruction": {"parts": [{"text": system}]},
        "contents": [{"parts": [{"text": user}]}],
    }).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read())
    return result["candidates"][0]["content"]["parts"][0]["text"]


def call_llm(provider: str, model: str, api_key: str, system: str, user: str) -> str:
    if provider == "anthropic":
        return call_anthropic(model, api_key, system, user)
    elif provider == "openai":
        return call_openai(model, api_key, system, user)
    elif provider == "gemini":
        return call_gemini(model, api_key, system, user)
    raise ValueError(f"Unknown provider: {provider}")


def load_evals(eval_dir: str) -> list:
    evals = []
    for path in sorted(glob.glob(os.path.join(eval_dir, "*.json"))):
        with open(path) as f:
            evals.append(json.load(f))
    return evals


def run_eval(eval_data: dict, agent_provider: str, agent_model: str, agent_key: str,
             judge_provider: str, judge_model: str, judge_key: str, verbose: bool) -> dict:
    name = eval_data["name"]
    query = eval_data["query"]
    criteria = eval_data["success_criteria"]

    if verbose:
        print(f"\n--- Running: {name} ---")
        print(f"  Query: {query[:80]}...")

    # Step 1: Get agent response
    system = (
        "You are an AI coding agent with the AgentSpan skill installed. "
        "Help the user with their request using the agentspan CLI and Python SDK."
    )
    try:
        agent_response = call_llm(agent_provider, agent_model, agent_key, system, query)
    except Exception as e:
        return {"name": name, "passed": False, "score": 0, "error": str(e)}

    if verbose:
        print(f"  Agent response: {agent_response[:200]}...")

    # Step 2: Judge the response
    judge_prompt = (
        f"Evaluate the following AI agent response against success criteria.\n\n"
        f"USER QUERY: {query}\n\n"
        f"AGENT RESPONSE:\n{agent_response}\n\n"
        f"SUCCESS CRITERIA:\n" + "\n".join(f"- {c}" for c in criteria) + "\n\n"
        f"For each criterion, mark PASS or FAIL. Then give an overall score 0-100.\n"
        f"Respond in JSON: {{\"criteria_results\": [{{\"criterion\": \"...\", \"result\": \"PASS|FAIL\"}}], \"score\": N, \"summary\": \"...\"}}"
    )
    try:
        judge_response = call_llm(judge_provider, judge_model, judge_key,
                                   "You are an evaluation judge. Respond only in valid JSON.", judge_prompt)
        # Extract JSON from response
        start = judge_response.find("{")
        end = judge_response.rfind("}") + 1
        judge_result = json.loads(judge_response[start:end])
    except Exception as e:
        return {"name": name, "passed": False, "score": 0, "error": f"Judge error: {e}"}

    score = judge_result.get("score", 0)
    passed = score >= 70

    if verbose:
        print(f"  Score: {score}/100 {'PASS' if passed else 'FAIL'}")
        print(f"  Summary: {judge_result.get('summary', 'N/A')}")

    return {
        "name": name,
        "passed": passed,
        "score": score,
        "summary": judge_result.get("summary", ""),
        "criteria_results": judge_result.get("criteria_results", []),
    }


def main():
    parser = argparse.ArgumentParser(description="AgentSpan Skills evaluation runner")
    parser.add_argument("--model", default=DEFAULT_AGENT_MODEL, help="Agent model")
    parser.add_argument("--judge-model", default=DEFAULT_JUDGE_MODEL, help="Judge model")
    parser.add_argument("--provider", help="Agent provider (auto-detected from model)")
    parser.add_argument("--judge-provider", help="Judge provider (auto-detected from model)")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--json", action="store_true", dest="json_output", help="JSON output")
    parser.add_argument("--output", help="Output file for JSON results")
    parser.add_argument("--eval-dir", default="evaluations", help="Evaluations directory")
    args = parser.parse_args()

    agent_provider = args.provider or detect_provider(args.model)
    judge_provider = args.judge_provider or detect_provider(args.judge_model)
    agent_key = get_api_key(agent_provider)
    judge_key = get_api_key(judge_provider)

    evals = load_evals(args.eval_dir)
    if not evals:
        print("No evaluations found", file=sys.stderr)
        sys.exit(1)

    print(f"Running {len(evals)} evaluations")
    print(f"Agent: {args.model} ({agent_provider})")
    print(f"Judge: {args.judge_model} ({judge_provider})")

    results = []
    for eval_data in evals:
        result = run_eval(eval_data, agent_provider, args.model, agent_key,
                          judge_provider, args.judge_model, judge_key, args.verbose)
        results.append(result)
        status = "PASS" if result["passed"] else "FAIL"
        if not args.json_output:
            print(f"  {status}  {result['name']} ({result['score']}/100)")

    passed = sum(1 for r in results if r["passed"])
    total = len(results)

    if args.json_output or args.output:
        report = {"model": args.model, "judge": args.judge_model, "passed": passed, "total": total, "results": results}
        output = json.dumps(report, indent=2)
        if args.output:
            with open(args.output, "w") as f:
                f.write(output)
            print(f"Results written to {args.output}")
        else:
            print(output)
    else:
        print(f"\nResults: {passed}/{total} passed")

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
