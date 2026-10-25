"""Read-only IAM-authenticated compliance report Lambda."""

from __future__ import annotations

import base64
import binascii
import json
import os
from typing import Any

import boto3
from boto3.dynamodb.conditions import Attr

from cloud_guard.report import build_report
from cloud_guard.storage import utc_now


def _decode_token(token: str | None) -> dict[str, str] | None:
    if not token:
        return None
    try:
        key = json.loads(base64.urlsafe_b64decode(token.encode("ascii") + b"=="))
    except (UnicodeError, binascii.Error, json.JSONDecodeError):
        raise ValueError("continuation_token is invalid") from None
    if (
        not isinstance(key, dict)
        or set(key) != {"finding_arn", "sort_key"}
        or not all(isinstance(value, str) for value in key.values())
    ):
        raise ValueError("continuation_token is invalid")
    return key


def _encode_token(key: dict[str, Any] | None) -> str | None:
    if key is None:
        return None
    return base64.urlsafe_b64encode(json.dumps(key).encode("utf-8")).decode("ascii").rstrip("=")


def handler(_event: dict[str, Any], _context: Any) -> dict[str, Any]:
    parameters = _event.get("queryStringParameters") or {}
    try:
        limit = int(parameters.get("limit", "200"))
        if not 1 <= limit <= 500:
            raise ValueError
        exclusive_start_key = _decode_token(parameters.get("continuation_token"))
    except (TypeError, ValueError):
        return {
            "statusCode": 400,
            "headers": {"content-type": "application/json"},
            "body": json.dumps(
                {"message": "limit must be 1–500 and continuation_token must be valid."}
            ),
        }

    table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    state_items: list[dict[str, Any]] = []
    scan_args: dict[str, Any] = {
        "FilterExpression": Attr("sort_key").eq("STATE"),
    }
    if exclusive_start_key:
        scan_args["ExclusiveStartKey"] = exclusive_start_key
    scanned = 0
    next_key = None
    while len(state_items) < limit and scanned < 1000:
        scan_args["Limit"] = min(limit - len(state_items), 1000 - scanned)
        response = table.scan(**scan_args)
        state_items.extend(response.get("Items", []))
        scanned += response.get("ScannedCount", 0)
        next_key = response.get("LastEvaluatedKey")
        if not next_key:
            break
        scan_args["ExclusiveStartKey"] = next_key

    fields = (
        "finding_arn",
        "account_id",
        "region",
        "control_id",
        "resource_type",
        "resource_id",
        "title",
        "severity",
        "risk_score",
        "status",
        "updated_at",
    )
    findings = [{key: item[key] for key in fields if key in item} for item in state_items]
    report = build_report(findings, utc_now())
    report["pagination"] = {
        "limit": limit,
        "next_token": _encode_token(next_key),
        "truncated": next_key is not None,
    }
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(report),
    }
