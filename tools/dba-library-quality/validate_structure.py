#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]

RULES = {
    "standards": {
        "glob": "*/README.md",
        "sections": [
            "## Purpose", "## Scope", "## Requirements",
            "### Required", "### Recommended", "### Not allowed",
            "## Default configuration", "## Exceptions",
            "## Validation", "## Ownership", "## Review cycle", "## References",
        ],
    },
    "monitoring": {
        "glob": "*/README.md",
        "sections": [
            "## Purpose", "## Signals / Metrics", "## Alert vs Trend",
            "## Baseline", "## Correlation", "## Severity",
            "## Validation", "## Troubleshooting", "## Runbooks",
            "## Sources of truth",
        ],
    },
    "troubleshooting": {
        "glob": "*/README.md",
        "sections": ["## Symptoms"],
    },
}

RUNBOOK_FILES = ["README.md", "PRECHECK.md", "RUNBOOK.md", "VALIDATION.md", "ROLLBACK.md"]
ADR_SECTIONS = [
    "## Context", "## Decision drivers", "## Considered options",
    "## Decision", "## Consequences", "## Validation",
    "## Revisit when", "## References",
]

errors = []

def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")

def require_sections(path: Path, sections):
    text = read(path)
    missing = [s for s in sections if s not in text]
    if missing:
        errors.append(f"{path.relative_to(ROOT)}: missing sections: {', '.join(missing)}")

for area, rule in RULES.items():
    base = ROOT / area
    for path in sorted(base.glob(rule["glob"])):
        require_sections(path, rule["sections"])

runbooks = ROOT / "runbooks"
for directory in sorted(p for p in runbooks.iterdir() if p.is_dir()):
    missing = [name for name in RUNBOOK_FILES if not (directory / name).exists()]
    if missing:
        errors.append(f"{directory.relative_to(ROOT)}: missing runbook files: {', '.join(missing)}")

adr_dir = ROOT / "architecture" / "adr"
for path in sorted(adr_dir.glob("ADR-*.md")):
    require_sections(path, ADR_SECTIONS)
    text = read(path)
    if "- Status:" not in text:
        errors.append(f"{path.relative_to(ROOT)}: missing ADR Status")
    if "- Date:" not in text:
        errors.append(f"{path.relative_to(ROOT)}: missing ADR Date")

if errors:
    print("DBA Library structure validation FAILED")
    for error in errors:
        print(f"ERROR: {error}")
    sys.exit(1)

print("DBA Library structure validation PASSED")
print(f"Validated standards, monitoring modules, {len([p for p in runbooks.iterdir() if p.is_dir()])} runbooks and {len(list(adr_dir.glob('ADR-*.md')))} ADRs.")
