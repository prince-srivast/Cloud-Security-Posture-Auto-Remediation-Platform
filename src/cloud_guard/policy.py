"""Pure policy helpers shared by event processing and remediation."""

from __future__ import annotations

import ipaddress
from typing import Any

SUPPORTED_CONTROLS: dict[str, str] = {
    "S3.1": "s3",
    "S3.2": "s3",
    "S3.3": "s3",
    "EC2.13": "security-group",
    "EC2.14": "security-group",
    "EC2.19": "security-group",
}


def risk_score(severity: Any, control_id: str) -> int:
    """Return a stable 0–100 score from Security Hub severity and control."""
    labels = {
        "INFORMATIONAL": 5,
        "LOW": 25,
        "MEDIUM": 50,
        "HIGH": 75,
        "CRITICAL": 95,
    }
    label = str((severity or {}).get("Label", "INFORMATIONAL")).upper()
    score = labels.get(label, 5)
    if control_id in {"S3.2", "S3.3", "EC2.13", "EC2.14", "EC2.19"}:
        score = min(100, score + 10)
    return score


def supported_finding(finding: dict[str, Any]) -> dict[str, str] | None:
    """Extract a supported control and its one actionable AWS resource."""
    control_id = str((finding.get("Compliance") or {}).get("SecurityControlId", ""))
    resource_type = SUPPORTED_CONTROLS.get(control_id)
    if resource_type is None:
        return None

    expected_type = "AwsS3Bucket" if resource_type == "s3" else "AwsEc2SecurityGroup"
    resources = [
        resource
        for resource in finding.get("Resources", [])
        if resource.get("Type") == expected_type and resource.get("Id")
    ]
    if len(resources) != 1:
        return None

    resource_id = str(resources[0]["Id"])
    if resource_type == "s3":
        prefix = "arn:aws:s3:::"
        resource_id = resource_id.removeprefix(prefix)
        if not resource_id or "/" in resource_id:
            return None
    else:
        if resource_id.startswith("arn:"):
            resource_id = resource_id.rsplit("/", 1)[-1]
        if not resource_id.startswith("sg-"):
            return None

    return {"control_id": control_id, "resource_type": resource_type, "resource_id": resource_id}


def public_ingress_permissions(
    permissions: list[dict[str, Any]],
    control_id: str,
    authorized_tcp_ports: set[int],
) -> list[dict[str, Any]]:
    """Build narrow revoke requests for the specific supported security control."""
    revocations: list[dict[str, Any]] = []
    for permission in permissions:
        if permission.get("IpProtocol") != "tcp":
            continue
        start = permission.get("FromPort")
        end = permission.get("ToPort")
        if not isinstance(start, int) or not isinstance(end, int) or start > end:
            continue

        if control_id == "EC2.13":
            source_keys = (("IpRanges", "CidrIp"),)
            denied_ranges = [(start, end)] if start == end and start in {22, 3389} else []
        elif control_id == "EC2.14":
            source_keys = (("Ipv6Ranges", "CidrIpv6"),)
            denied_ranges = [(start, end)] if start == end and start in {22, 3389} else []
        elif control_id == "EC2.19":
            source_keys = (("IpRanges", "CidrIp"), ("Ipv6Ranges", "CidrIpv6"))
            includes_authorized_port = any(start <= port <= end for port in authorized_tcp_ports)
            denied_ranges = [] if includes_authorized_port else [(start, end)]
        else:
            continue

        for range_key, cidr_key in source_keys:
            for source in permission.get(range_key, []):
                try:
                    network = ipaddress.ip_network(source[cidr_key], strict=False)
                except (KeyError, ValueError):
                    continue
                if network.prefixlen != 0:
                    continue
                for from_port, to_port in denied_ranges:
                    revocations.append(
                        {
                            "IpProtocol": "tcp",
                            "FromPort": from_port,
                            "ToPort": to_port,
                            range_key: [{cidr_key: str(network)}],
                        }
                    )
    return revocations
