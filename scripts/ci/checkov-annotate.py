#!/usr/bin/env python3
"""Turn checkov JSON output into GitHub Actions annotations.

Usage: checkov-annotate.py <report.json> <scanned-root>
Exits 1 if any check failed, so the step still fails the job.
"""
import json
import sys

report_path, root = sys.argv[1], sys.argv[2].rstrip("/")
with open(report_path) as fh:
    raw = fh.read().strip()

if not raw:
    sys.exit(0)

data = json.loads(raw)
reports = data if isinstance(data, list) else [data]
failed = 0

for report in reports:
    for check in report.get("results", {}).get("failed_checks", []):
        failed += 1
        path = check.get("file_path", "").lstrip("/")
        # Kustomize results point at rendered output; fall back to the root.
        file_ref = f"{root}/{path}" if path and not path.startswith(root) else (path or root)
        line = (check.get("file_line_range") or [1])[0] or 1
        msg = f"{check['check_name']} ({check.get('resource', '')})"
        print(f"::error file={file_ref},line={line},title={check['check_id']}::{msg}")

print(f"checkov: {failed} failed check(s)")
sys.exit(1 if failed else 0)
