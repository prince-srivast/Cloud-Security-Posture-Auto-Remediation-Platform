"""DynamoDB state and append-only audit helpers."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import uuid4


def utc_now() -> str:
    return datetime.now(UTC).isoformat(timespec="milliseconds")


def audit(
    table: Any,
    finding_arn: str,
    action: str,
    actor: str,
    details: dict[str, Any] | None = None,
) -> None:
    table.put_item(
        Item={
            "finding_arn": finding_arn,
            "sort_key": f"AUDIT#{utc_now()}#{uuid4()}",
            "action": action,
            "actor": actor,
            "details": details or {},
            "created_at": utc_now(),
        },
        ConditionExpression="attribute_not_exists(finding_arn) AND attribute_not_exists(sort_key)",
    )
