#!/usr/bin/env python3
import json, sys

SEVERITY_MAP = {"CRITICAL": "error", "HIGH": "error", "MEDIUM": "warning", "LOW": "note", "INFORMATIONAL": "note", "UNTRIAGED": "warning"}

def get_level(severity, exploit_available):
    level = SEVERITY_MAP.get(severity, "warning")
    if exploit_available == "YES" and level == "warning":
        level = "error"
    return level

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
    pkg_details = f.get("packageVulnerabilityDetails", {})
    cve_id = pkg_details.get("vulnerabilityId", f.get("title", "UNKNOWN"))
    severity = f.get("severity", "INFORMATIONAL")
    description = f.get("description", cve_id)
    source_url = pkg_details.get("sourceUrl", "")
    fix_available = f.get("fixAvailable", "NO")
    exploit_available = f.get("exploitAvailable", "NO")

    packages = pkg_details.get("vulnerablePackages", [])
    pkg = packages[0] if packages else {}
    pkg_name = pkg.get("name", "")
    pkg_version = pkg.get("version", "")
    fixed_in = pkg.get("fixedInVersion", "")
    file_path = pkg.get("filePath", "Dockerfile").lstrip("/")

    cvss_scores = pkg_details.get("cvss", [])
    best_cvss = max((c.get("baseScore", 0) for c in cvss_scores), default=None)

    level = get_level(severity, exploit_available)

    lines = [description, ""]
    if pkg_name:
        lines.append(f"Package: {pkg_name} {pkg_version}")
    file_path = pkg.get("filePath", "")
    if fixed_in:
        lines.append(f"Fixed in: {fixed_in}")
    if best_cvss is not None:
        lines.append(f"CVSS score: {best_cvss}")
    lines.append(f"Fix available: {fix_available}")
    lines.append(f"Exploit available: {exploit_available}")

    full_description = "\n".join(lines)

    if cve_id not in seen_rules:
        seen_rules.add(cve_id)
        rules.append({
            "id": cve_id,
            "shortDescription": {"text": f"{cve_id} - {pkg_name}" if pkg_name else cve_id},
            "fullDescription": {"text": full_description},
            "helpUri": source_url,
            "defaultConfiguration": {"level": level},
            "properties": {"security-severity": str(best_cvss) if best_cvss is not None else "0.0"}
        })

    results.append({
        "ruleId": cve_id,
        "level": level,
        "message": {"text": full_description},
        "locations": [{"physicalLocation": {"artifactLocation": {"uri": file_path}}}]
    })

print(json.dumps(sarif, indent=2))
