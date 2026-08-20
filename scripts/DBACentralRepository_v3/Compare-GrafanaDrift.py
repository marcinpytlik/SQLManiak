import copy
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

dashboard_dir = pathlib.Path(os.environ["DASHBOARD_DIR"])
grafana_url = os.environ["GRAFANA_URL"].rstrip("/")
grafana_token = os.environ["GRAFANA_TOKEN"]
namespace = os.environ.get("GRAFANA_NAMESPACE", "default")
folder_uid = os.environ.get("GRAFANA_FOLDER_UID", "dbacentralrepository")

files = sorted(dashboard_dir.glob("*.json"))
if not files:
    print(f"ERROR: no dashboard JSON files found in {dashboard_dir}", file=sys.stderr)
    sys.exit(2)

def load_json(path):
    with path.open("r", encoding="utf-8-sig") as f:
        return json.load(f)

def normalize(obj):
    spec = copy.deepcopy(obj.get("spec") or {})
    spec.pop("version", None)

    tags = list(spec.get("tags") or [])
    for tag in ("DBACentralRepository", "ManagedByGitHub"):
        if tag not in tags:
            tags.append(tag)
    spec["tags"] = sorted(tags)

    metadata = obj.get("metadata") or {}

    return {
        "apiVersion": obj.get("apiVersion"),
        "kind": obj.get("kind"),
        "metadata": {
            "name": metadata.get("name"),
            "folder": folder_uid,
        },
        "spec": spec,
    }

def get_live(api_version, name):
    api_group, api_ver = api_version.rsplit("/", 1)
    url = (
        f"{grafana_url}/apis/{api_group}/{api_ver}"
        f"/namespaces/{namespace}/dashboards/{name}"
    )
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {grafana_token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return 404, None
        body = exc.read().decode("utf-8", errors="replace")
        print(f"ERROR: GET {url} returned HTTP {exc.code}: {body}", file=sys.stderr)
        raise

drifted = []
missing = []

for path in files:
    desired = load_json(path)

    api_version = desired.get("apiVersion")
    kind = desired.get("kind")
    metadata = desired.get("metadata") or {}
    spec = desired.get("spec") or {}
    name = metadata.get("name")
    title = spec.get("title")

    if not api_version or not api_version.startswith("dashboard.grafana.app/"):
        print(f"ERROR: {path.name}: invalid apiVersion {api_version!r}", file=sys.stderr)
        sys.exit(2)
    if kind != "Dashboard":
        print(f"ERROR: {path.name}: kind must be Dashboard", file=sys.stderr)
        sys.exit(2)
    if not name:
        print(f"ERROR: {path.name}: metadata.name is required", file=sys.stderr)
        sys.exit(2)

    status, live = get_live(api_version, name)

    if status == 404:
        print(f"MISSING: {name} ({title})")
        missing.append(name)
        continue

    if normalize(desired) == normalize(live):
        print(f"OK: {name} ({title})")
    else:
        print(f"DRIFT: {name} ({title})")
        drifted.append(name)

print()
print(f"Drifted dashboards: {len(drifted)}")
print(f"Missing dashboards: {len(missing)}")

summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    with open(summary, "a", encoding="utf-8") as f:
        f.write("## Grafana drift check\n\n")
        f.write("| Result | Count |\n")
        f.write("|---|---:|\n")
        f.write(f"| Drifted dashboards | {len(drifted)} |\n")
        f.write(f"| Missing dashboards | {len(missing)} |\n")

if drifted or missing:
    sys.exit(1)
