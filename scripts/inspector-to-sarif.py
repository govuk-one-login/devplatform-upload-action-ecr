#!/usr/bin/env python3
import json, sys

SEVERITY_MAP = {"CRITICAL": "error", "HIGH": "error", "MEDIUM": "warning", "LOW": "note", "INFORMATIONAL": "note"}

findings = json.load(sys.stdin).get("findings", [])

sarif = {
    "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
    "version": "2.1.0",
    "runs": [{
        "tool": {"driver": {"name": "AWS Inspector", "rules": []}},
        "results": []
    }]
}

rules = sarif["runs"][0]["tool"]["driver"]["rules"]
results = sarif["runs"][0]["results"]
seen_rules = set()

for f in findings:
    cve = f.get("title", "UNKNOWN")
    severity = f.get("severity", "INFORMATIONAL")
    description = f.get("description", cve)
    uri = next((r.get("url", "") for r in f.get("packageVulnerabilityDetails", {}).get("referenceUrls", [{}])), "")

    if cve not in seen_rules:
        seen_rules.add(cve)
        rules.append({
            "id": cve,
            "shortDescription": {"text": description},
            "helpUri": uri,
            "defaultConfiguration": {"level": SEVERITY_MAP.get(severity, "note")}
        })

    results.append({
        "ruleId": cve,
        "level": SEVERITY_MAP.get(severity, "note"),
        "message": {"text": description},
        "locations": [{"physicalLocation": {"artifactLocation": {"uri": "Dockerfile"}}}]
    })

print(json.dumps(sarif, indent=2))
