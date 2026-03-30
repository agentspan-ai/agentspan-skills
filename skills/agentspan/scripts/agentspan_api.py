#!/usr/bin/env python3
"""AgentSpan REST API fallback script.

Stdlib-only (no third-party deps). Use when the agentspan CLI cannot be installed.

Usage:
    export AGENTSPAN_SERVER_URL=http://localhost:8080/api
    python3 agentspan_api.py list-agents
    python3 agentspan_api.py start-agent --config agent.json
    python3 agentspan_api.py get-execution --id <workflow-id>
    python3 agentspan_api.py search-executions --status FAILED --size 10
    python3 agentspan_api.py respond --id <workflow-id> --approve
    python3 agentspan_api.py stream --id <workflow-id>
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error

SERVER_URL = os.environ.get("AGENTSPAN_SERVER_URL", "http://localhost:8080/api")
AUTH_KEY = os.environ.get("AGENTSPAN_AUTH_KEY", "")
AUTH_SECRET = os.environ.get("AGENTSPAN_AUTH_SECRET", "")
AUTH_TOKEN = os.environ.get("AGENTSPAN_AUTH_TOKEN", "")

_cached_token = None


def get_token() -> str:
    global _cached_token
    if AUTH_TOKEN:
        return AUTH_TOKEN
    if _cached_token:
        return _cached_token
    if AUTH_KEY and AUTH_SECRET:
        data = json.dumps({"keyId": AUTH_KEY, "keySecret": AUTH_SECRET}).encode()
        req = urllib.request.Request(
            f"{SERVER_URL}/token",
            data=data,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read())
            _cached_token = result.get("token", "")
            return _cached_token
    return ""


def api_request(method: str, path: str, body=None, retries=3) -> dict:
    url = f"{SERVER_URL}{path}"
    headers = {"Content-Type": "application/json"}
    token = get_token()
    if token:
        headers["Authorization"] = f"Bearer {token}"

    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read()
                if raw:
                    return json.loads(raw)
                return {}
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                wait = 2 ** attempt
                print(f"Retrying in {wait}s (HTTP {e.code})...", file=sys.stderr)
                time.sleep(wait)
                continue
            body_text = e.read().decode() if e.fp else ""
            print(f"Error: HTTP {e.code} {e.reason}: {body_text}", file=sys.stderr)
            sys.exit(1)
        except urllib.error.URLError as e:
            print(f"Error: {e.reason}", file=sys.stderr)
            sys.exit(1)
    return {}


def handle_list_agents(args):
    result = api_request("GET", "/agent/list")
    if isinstance(result, list):
        for agent in result:
            print(f"{agent.get('name', 'unknown'):<40} v{agent.get('version', 1)}")
    else:
        print(json.dumps(result, indent=2))


def handle_get_agent(args):
    result = api_request("GET", f"/agent/get/{args.name}")
    print(json.dumps(result, indent=2))


def handle_delete_agent(args):
    api_request("DELETE", f"/agent/delete/{args.name}")
    print(f"Deleted: {args.name}")


def handle_start_agent(args):
    with open(args.config) as f:
        config = json.load(f)
    if args.prompt:
        config["input"] = {"prompt": args.prompt}
    result = api_request("POST", "/agent/start", config)
    wf_id = result.get("workflowId", result)
    print(f"Started: {wf_id}")


def handle_get_execution(args):
    result = api_request("GET", f"/agent/executions/{args.id}")
    print(json.dumps(result, indent=2))


def handle_search_executions(args):
    params = []
    if args.status:
        params.append(f"status={args.status}")
    if args.size:
        params.append(f"size={args.size}")
    if args.name:
        params.append(f"name={args.name}")
    query = "&".join(params)
    path = f"/agent/executions?{query}" if query else "/agent/executions"
    result = api_request("GET", path)
    if "results" in result:
        for ex in result["results"]:
            print(f"{ex.get('workflowId', ''):<40} {ex.get('workflowName', ''):<25} {ex.get('status', '')}")
    else:
        print(json.dumps(result, indent=2))


def handle_respond(args):
    action = "approve" if args.approve else "reject"
    body = {"action": action}
    if args.reason:
        body["reason"] = args.reason
    api_request("POST", f"/agent/{args.id}/respond", body)
    print(f"Response sent: {action}")


def handle_stream(args):
    url = f"{SERVER_URL}/agent/stream/{args.id}"
    headers = {}
    token = get_token()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    headers["Accept"] = "text/event-stream"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            for line in resp:
                line = line.decode().strip()
                if line.startswith("data:"):
                    data = line[5:].strip()
                    try:
                        event = json.loads(data)
                        print(f"[{event.get('type', 'event')}] {event.get('content', '')}")
                    except json.JSONDecodeError:
                        print(data)
    except KeyboardInterrupt:
        print("\nStream stopped.")


def handle_status(args):
    result = api_request("GET", f"/agent/{args.id}/status")
    print(json.dumps(result, indent=2))


def main():
    parser = argparse.ArgumentParser(description="AgentSpan REST API fallback")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list-agents", help="List all agents")

    p = sub.add_parser("get-agent", help="Get agent definition")
    p.add_argument("--name", required=True)

    p = sub.add_parser("delete-agent", help="Delete agent")
    p.add_argument("--name", required=True)

    p = sub.add_parser("start-agent", help="Start agent from config")
    p.add_argument("--config", required=True, help="JSON config file")
    p.add_argument("--prompt", help="Optional prompt")

    p = sub.add_parser("get-execution", help="Get execution details")
    p.add_argument("--id", required=True)

    p = sub.add_parser("search-executions", help="Search executions")
    p.add_argument("--status", help="RUNNING|COMPLETED|FAILED|TERMINATED|TIMED_OUT")
    p.add_argument("--size", type=int, default=10)
    p.add_argument("--name", help="Filter by agent name")

    p = sub.add_parser("respond", help="Respond to HITL task")
    p.add_argument("--id", required=True)
    p.add_argument("--approve", action="store_true")
    p.add_argument("--reject", action="store_true")
    p.add_argument("--reason", help="Rejection reason")

    p = sub.add_parser("stream", help="Stream agent events")
    p.add_argument("--id", required=True)

    p = sub.add_parser("status", help="Get execution status")
    p.add_argument("--id", required=True)

    args = parser.parse_args()
    handlers = {
        "list-agents": handle_list_agents,
        "get-agent": handle_get_agent,
        "delete-agent": handle_delete_agent,
        "start-agent": handle_start_agent,
        "get-execution": handle_get_execution,
        "search-executions": handle_search_executions,
        "respond": handle_respond,
        "stream": handle_stream,
        "status": handle_status,
    }
    handlers[args.command](args)


if __name__ == "__main__":
    main()
