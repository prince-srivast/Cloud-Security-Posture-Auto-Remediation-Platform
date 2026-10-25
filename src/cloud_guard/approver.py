"""IAM-authenticated approval API Lambda."""

from __future__ import annotations

import json
import os
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from cloud_guard.storage import audit, utc_now


def _response(status_code: int, message: str) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"message": message}),
    }


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    caller = event.get("requestContext", {}).get("identity", {}).get("userArn")
    if not caller:
        return _response(403, "An IAM-authenticated caller is required.")

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, "Request body must be valid JSON.")
    if not isinstance(body, dict):
        return _response(400, "Request body must be a JSON object.")
    finding_arn = body.get("finding_arn")
    decision = body.get("decision")
    if not isinstance(finding_arn, str) or not finding_arn.startswith("arn:"):
        return _response(400, "A valid finding_arn is required.")
    if decision not in {"approve", "reject"}:
        return _response(400, "decision must be 'approve' or 'reject'.")

    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(os.environ["TABLE_NAME"])
    next_status = "APPROVED" if decision == "approve" else "REJECTED"
    try:
        table.update_item(
            Key={"finding_arn": finding_arn, "sort_key": "STATE"},
            UpdateExpression="SET #status = :status, decided_by = :actor, updated_at = :now",
            ConditionExpression="#status = :pending",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":status": next_status,
                ":pending": "WAITING_APPROVAL",
                ":actor": caller,
                ":now": utc_now(),
            },
        )
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return _response(409, "Finding is missing or is no longer awaiting approval.")
        raise

    audit(table, finding_arn, f"APPROVAL_{decision.upper()}", caller)
    if decision == "reject":
        return _response(200, "Finding rejected; no remediation was run.")

    try:
        result = boto3.client("lambda").invoke(
            FunctionName=os.environ["REMEDIATOR_FUNCTION_NAME"],
            InvocationType="RequestResponse",
            Payload=json.dumps({"finding_arn": finding_arn}).encode("utf-8"),
        )
        if result.get("FunctionError"):
            return _response(
                502, "Approval recorded, but remediation failed. Check the audit record."
            )
        payload = json.loads(result["Payload"].read())
        if payload.get("status") != "REMEDIATED":
            return _response(502, "Approval recorded, but remediation did not complete.")
    except (BotoCoreError, ClientError):
        table.update_item(
            Key={"finding_arn": finding_arn, "sort_key": "STATE"},
            UpdateExpression="SET #status = :status, updated_at = :now",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":status": "DISPATCH_FAILED",
                ":now": utc_now(),
            },
        )
        audit(table, finding_arn, "REMEDIATION_DISPATCH_FAILED", caller)
        raise

    return _response(200, "Finding approved and remediated.")
