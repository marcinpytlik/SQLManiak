#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

GRAFANA_URL = os.environ["GRAFANA_URL"].rstrip("/")
ADMIN_TOKEN = os.environ["GRAFANA_ROTATION_ADMIN_TOKEN"]
DEPLOY_SA_ID = int(os.environ["GRAFANA_DEPLOY_SERVICE_ACCOUNT_ID"])
REMIND_DAYS = int(os.environ.get("GRAFANA_REMIND_WHEN_DAYS_LEFT", "35"))
PREFIX = "sqlmaniak-deploy-auto-"

REPOSITORY = os.environ["GITHUB_REPOSITORY"]
GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
ISSUE_TITLE = "[Grafana] Deployment token rotation approaching"

def grafana_json(path):
    req = urllib.request.Request(
        f"{GRAFANA_URL}{path}",
        headers={
            "Authorization": f"Bearer {ADMIN_TOKEN}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)

def github_json(method, path, payload=None):
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {GITHUB_TOKEN}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2026-03-10",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        raw = response.read()
        return json.loads(raw.decode("utf-8")) if raw else None

def active_managed_token():
    tokens = grafana_json(f"/api/serviceaccounts/{DEPLOY_SA_ID}/tokens")
    candidates = [
        t for t in tokens
        if str(t.get("name", "")).startswith(PREFIX)
        and not bool(t.get("hasExpired", False))
    ]
    if not candidates:
        return None
    return max(
        candidates,
        key=lambda t: int(t.get("secondsUntilExpiration") or -1)
    )

def existing_issue():
    owner, repo = REPOSITORY.split("/", 1)
    issues = github_json(
        "GET",
        f"/repos/{owner}/{repo}/issues?state=open&per_page=100"
    )
    for issue in issues or []:
        if issue.get("title") == ISSUE_TITLE and "pull_request" not in issue:
            return issue
    return None

def create_issue(message):
    owner, repo = REPOSITORY.split("/", 1)
    return github_json(
        "POST",
        f"/repos/{owner}/{repo}/issues",
        {
            "title": ISSUE_TITLE,
            "body": message,
        },
    )

def close_issue(issue_number):
    owner, repo = REPOSITORY.split("/", 1)
    github_json(
        "PATCH",
        f"/repos/{owner}/{repo}/issues/{issue_number}",
        {"state": "closed"},
    )

def main():
    token = active_managed_token()
    issue = existing_issue()

    if token is None:
        message = (
            "No managed Grafana deployment token was found. "
            "Run **Rotate Grafana tokens** with `force_rotation=true`."
        )
        print(message)
        if issue is None:
            create_issue(message)
        sys.exit(1)

    expiration = token.get("expiration")
    remaining = token.get("secondsUntilExpiration")

    if not expiration or remaining is None:
        message = (
            f"Managed Grafana token `{token.get('name')}` has no usable expiration. "
            "A bounded-TTL token should be created."
        )
        print(message)
        if issue is None:
            create_issue(message)
        sys.exit(1)

    days_left = int(remaining) / 86400
    print(f"Managed deployment token: {token.get('name')}")
    print(f"Days remaining: {days_left:.1f}")

    if days_left <= REMIND_DAYS:
        message = (
            f"Grafana deployment token `{token.get('name')}` has "
            f"approximately **{days_left:.1f} days** remaining.\n\n"
            "Automatic rotation is configured. Verify that the scheduled "
            "`Rotate Grafana tokens` workflow completes successfully."
        )
        if issue is None:
            create_issue(message)
            print("Reminder issue created.")
        else:
            print(f"Reminder issue already open: #{issue['number']}")
    else:
        if issue is not None:
            close_issue(issue["number"])
            print(f"Healthy token lifetime; closed reminder issue #{issue['number']}.")
        else:
            print("Healthy token lifetime; no reminder required.")

if __name__ == "__main__":
    main()
