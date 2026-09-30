#!/usr/bin/env python3
from pathlib import Path
from urllib.parse import unquote
import re
import sys

ROOT = Path(__file__).resolve().parents[2]

SCAN_ROOTS = [
    ROOT / "readme.md",
    ROOT / "standards",
    ROOT / "monitoring",
    ROOT / "troubleshooting",
    ROOT / "runbooks",
    ROOT / "architecture",
    ROOT / "docs" / "DBA-LIBRARY-MAP.md",
    ROOT / "docs" / "CONTENT-LIFECYCLE.md",
    ROOT / "docs" / "LEGACY-CLEANUP.md",
]

LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")

def markdown_files(item: Path):
    if item.is_file():
        yield item
    elif item.is_dir():
        yield from item.rglob("*.md")

errors = []
checked = 0

for source_root in SCAN_ROOTS:
    for source in markdown_files(source_root):
        text = source.read_text(encoding="utf-8-sig")
        for raw in LINK_RE.findall(text):
            target = raw.strip().split()[0].strip("<>")
            if not target or target.startswith(("#", "http://", "https://", "mailto:")):
                continue

            target = unquote(target.split("#", 1)[0])
            if not target:
                continue

            resolved = (source.parent / target).resolve()
            try:
                resolved.relative_to(ROOT.resolve())
            except ValueError:
                errors.append(f"{source.relative_to(ROOT)} -> {raw}: target escapes repository")
                continue

            if resolved.is_dir():
                candidate = resolved / "README.md"
                candidate_lower = resolved / "readme.md"
                if not candidate.exists() and not candidate_lower.exists():
                    errors.append(f"{source.relative_to(ROOT)} -> {raw}: directory has no README.md")
            elif not resolved.exists():
                errors.append(f"{source.relative_to(ROOT)} -> {raw}: target does not exist")
            checked += 1

if errors:
    print("DBA Library internal link validation FAILED")
    for error in errors:
        print(f"ERROR: {error}")
    sys.exit(1)

print(f"DBA Library internal link validation PASSED ({checked} internal links checked).")
