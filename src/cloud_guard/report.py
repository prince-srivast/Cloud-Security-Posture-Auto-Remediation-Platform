"""Compliance report aggregation helpers."""

from __future__ import annotations

from collections import Counter
from typing import Any


def build_report(findings: list[dict[str, Any]], generated_at: str) -> dict[str, Any]:
    controls = Counter(item.get("control_id", "UNKNOWN") for item in findings)
    statuses = Counter(item.get("status", "UNKNOWN") for item in findings)
    return {
        "generated_at": generated_at,
        "summary": {
            "total_findings": len(findings),
            "average_risk_score": round(
                sum(int(item.get("risk_score", 0)) for item in findings) / len(findings), 2
            )
            if findings
            else 0,
            "by_control": dict(sorted(controls.items())),
            "by_status": dict(sorted(statuses.items())),
        },
        "findings": sorted(findings, key=lambda item: item.get("finding_arn", "")),
    }
