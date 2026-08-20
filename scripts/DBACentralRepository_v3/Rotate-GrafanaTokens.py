#!/usr/bin/env python3
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request

GRAFANA_URL = os.environ["GRAFANA_URL"].rstrip("/")
ADMIN_TOKEN = os.environ["GRAFANA_ROTATION_ADMIN_TOKEN"]
GH_SECRETS_TOKEN = os.environ["GH_SECRETS_TOKEN"]
REPOSITORY = os.environ["GITHUB_REPOSITORY"]

DEPLOY_SA_ID = int(os.environ["GRAFANA_DEPLOY_SERVICE_ACCOUNT_ID"])
ROTATOR_SA_ID = int(os.environ["GRAFANA_ROTATION_SERVICE_ACCOUNT_ID"])

TTL_DAYS = int(os.environ.get("GRAFANA_TOKEN_TTL_DAYS", "90"))
ROTATE_WHEN_DAYS_LEFT = int(os.environ.get("GRAFANA_ROTATE_WHEN_DAYS_LEFT", "30"))
FORCE_ROTATION = os.environ.get("FORCE_ROTATION", "false").lower() == "true"

DEPLOY_PREFIX = "sqlmaniak-deploy-auto-"
ROTATOR_PREFIX = "sqlmaniak-rotator-auto-"

LEGACY_DEPLOY_NAME = os.environ.get("GRAFANA_LEGACY_DEPLOY_TOKEN_NAME", "").strip()
LEGACY_ROTATOR_NAME = os.environ.get("GRAFANA_LEGACY_ROTATOR_TOKEN_NAME", "").strip()

TTL_SECONDS = TTL_DAYS * 86400
THRESHOLD_SECONDS = ROTATE_WHEN_DAYS_LEFT * 86400

def request_json(method, path, token, payload=None):
    url = f"{GRAFANA_URL}{path}"
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            if not raw:
                return response.status, None
            return response.status, json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {path} -> HTTP {exc.code}: {body}") from exc

def list_tokens(service_account_id, admin_token):
    _, payload = request_json(
        "GET",
        f"/api/serviceaccounts/{service_account_id}/tokens",
        admin_token,
    )
    return payload or []

def create_token(service_account_id, prefix, admin_token):
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    name = f"{prefix}{stamp}"
    _, payload = request_json(
        "POST",
        f"/api/serviceaccounts/{service_account_id}/tokens",
        admin_token,
        {"name": name, "secondsToLive": TTL_SECONDS},
    )
    token_id = int(payload["id"])
    key = payload["key"]
    print(f"Created Grafana token: {name} (id={token_id}, TTL={TTL_DAYS}d)")
    print(f"::add-mask::{key}")
    return token_id, name, key

def delete_token(service_account_id, token_id, admin_token):
    request_json(
        "DELETE",
        f"/api/serviceaccounts/{service_account_id}/tokens/{token_id}",
        admin_token,
    )

def verify_deploy_token(token):
    request_json(
        "GET",
        "/apis/dashboard.grafana.app/v2/namespaces/default/dashboards",
        token,
    )
    print("New deployment token verified against Dashboard Resource API.")

def verify_rotator_token(token):
    list_tokens(DEPLOY_SA_ID, token)
    print("New rotator token verified against Service Account API.")

def set_github_secret(secret_name, secret_value):
    if shutil.which("gh") is None:
        raise RuntimeError(
            "GitHub CLI 'gh' is not installed on the self-hosted runner. "
            "Install it once on Raspberry Pi: sudo apt update && sudo apt install -y gh"
        )

    env = os.environ.copy()
    env["GH_TOKEN"] = GH_SECRETS_TOKEN

    result = subprocess.run(
        ["gh", "secret", "set", secret_name, "--repo", REPOSITORY],
        input=secret_value,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Unable to update GitHub secret {secret_name}: {result.stderr.strip()}"
        )
    print(f"GitHub secret updated: {secret_name}")

def managed_tokens(tokens, prefix):
    return [
        token for token in tokens
        if str(token.get("name", "")).startswith(prefix)
        and not bool(token.get("hasExpired", False))
    ]

def best_managed_token(tokens, prefix):
    candidates = managed_tokens(tokens, prefix)
    if not candidates:
        return None

    def score(token):
        remaining = token.get("secondsUntilExpiration")
        if remaining is None:
            remaining = -1
        return int(remaining)

    return max(candidates, key=score)

def needs_rotation(tokens, prefix):
    if FORCE_ROTATION:
        return True, "forced"

    current = best_managed_token(tokens, prefix)
    if current is None:
        return True, "no managed token"

    expiration = current.get("expiration")
    remaining = current.get("secondsUntilExpiration")

    if not expiration:
        return True, "managed token has no expiration"

    if remaining is None:
        return True, "remaining lifetime is unknown"

    if int(remaining) <= THRESHOLD_SECONDS:
        days = int(remaining) / 86400
        return True, f"only {days:.1f} days remaining"

    days = int(remaining) / 86400
    return False, f"{days:.1f} days remaining"

def cleanup_old_tokens(service_account_id, tokens_before, new_id, prefix, legacy_name, auth_token):
    deleted = []

    for token in tokens_before:
        token_id = int(token["id"])
        name = str(token.get("name", ""))

        managed_old = name.startswith(prefix)
        legacy_old = bool(legacy_name) and name == legacy_name

        if token_id != new_id and (managed_old or legacy_old):
            delete_token(service_account_id, token_id, auth_token)
            deleted.append((token_id, name))
            print(f"Deleted old Grafana token: {name} (id={token_id})")

    return deleted

def rotate_deployment_token(admin_token):
    tokens_before = list_tokens(DEPLOY_SA_ID, admin_token)
    rotate, reason = needs_rotation(tokens_before, DEPLOY_PREFIX)

    print(f"Deployment token assessment: {reason}")
    if not rotate:
        return False, admin_token

    new_id, _, new_key = create_token(DEPLOY_SA_ID, DEPLOY_PREFIX, admin_token)

    try:
        verify_deploy_token(new_key)
        set_github_secret("GRAFANA_TOKEN", new_key)
    except Exception:
        print("Deployment rotation failed before cutover; removing newly created token.")
        delete_token(DEPLOY_SA_ID, new_id, admin_token)
        raise

    cleanup_old_tokens(
        DEPLOY_SA_ID,
        tokens_before,
        new_id,
        DEPLOY_PREFIX,
        LEGACY_DEPLOY_NAME,
        admin_token,
    )
    return True, admin_token

def rotate_rotator_token(current_admin_token):
    tokens_before = list_tokens(ROTATOR_SA_ID, current_admin_token)
    rotate, reason = needs_rotation(tokens_before, ROTATOR_PREFIX)

    print(f"Rotator token assessment: {reason}")
    if not rotate:
        return False, current_admin_token

    new_id, _, new_key = create_token(
        ROTATOR_SA_ID,
        ROTATOR_PREFIX,
        current_admin_token,
    )

    try:
        verify_rotator_token(new_key)
        set_github_secret("GRAFANA_ROTATION_ADMIN_TOKEN", new_key)
    except Exception:
        print("Rotator rotation failed before cutover; removing newly created token.")
        delete_token(ROTATOR_SA_ID, new_id, current_admin_token)
        raise

    # After GitHub secret cutover, use the new rotator token to retire old tokens.
    cleanup_old_tokens(
        ROTATOR_SA_ID,
        tokens_before,
        new_id,
        ROTATOR_PREFIX,
        LEGACY_ROTATOR_NAME,
        new_key,
    )
    return True, new_key

def write_summary(deploy_rotated, rotator_rotated):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as f:
        f.write("## Grafana token rotation\n\n")
        f.write("| Credential | Result |\n")
        f.write("|---|---|\n")
        f.write(f"| GRAFANA_TOKEN | {'rotated' if deploy_rotated else 'no rotation required'} |\n")
        f.write(f"| GRAFANA_ROTATION_ADMIN_TOKEN | {'rotated' if rotator_rotated else 'no rotation required'} |\n")
        f.write(f"\nTTL: {TTL_DAYS} days; rotation threshold: {ROTATE_WHEN_DAYS_LEFT} days remaining.\n")

def main():
    print("Starting Grafana zero-downtime token rotation.")
    print(f"Repository: {REPOSITORY}")
    print(f"Deploy service account ID: {DEPLOY_SA_ID}")
    print(f"Rotator service account ID: {ROTATOR_SA_ID}")
    print(f"TTL: {TTL_DAYS} days")
    print(f"Rotate with <= {ROTATE_WHEN_DAYS_LEFT} days remaining")
    print(f"Forced: {FORCE_ROTATION}")

    deploy_rotated, admin_token = rotate_deployment_token(ADMIN_TOKEN)
    rotator_rotated, _ = rotate_rotator_token(admin_token)

    write_summary(deploy_rotated, rotator_rotated)
    print("Token rotation completed successfully.")

if __name__ == "__main__":
    main()
