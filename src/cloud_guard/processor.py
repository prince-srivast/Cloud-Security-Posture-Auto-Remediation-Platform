"""Security Hub EventBridge finding intake Lambda."""

from __future__ import annotations

import json
import os
from typing import Any

import boto3
from botocore.exceptions import ClientError

from cloud_guard.policy import risk_score, supported_finding
from cloud_guard.storage import audit, utc_now


def handler(event: dict[str, Any], _context: Any) -> dict[str, int]:
    table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    notifier = boto3.client("sns")
    accepted = 0
    ignored = 0

    for finding in event.get("detail", {}).get("findings", []):
        resource = supported_finding(finding)
        finding_arn = finding.get("Id")
        if (
            resource is None
            or not isinstance(finding_arn, str)
            or not finding.get("AwsAccountId")
            or not finding.get("Region")
        ):
            ignored += 1
            continue
        if finding.get("RecordState", "ACTIVE") != "ACTIVE":
            ignored += 1
            continue

        score = risk_score(finding.get("Severity"), resource["control_id"])
        item = {
            "finding_arn": finding_arn,
            "sort_key": "STATE",
            "status": "WAITING_APPROVAL",
            "control_id": resource["control_id"],
            "resource_type": resource["resource_type"],
            "resource_id": resource["resource_id"],
            "account_id": finding.get("AwsAccountId", ""),
            "region": finding.get("Region", ""),
            "title": finding.get("Title", "Security Hub finding"),
            "severity": (finding.get("Severity") or {}).get("Label", "UNKNOWN"),
            "risk_score": score,
            "notification_sent": False,
            "updated_at": utc_now(),
        }
        is_new = True
        try:
            table.put_item(
                Item=item,
                ConditionExpression="attribute_not_exists(finding_arn)",
            )
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
                existing = table.get_item(
                    Key={"finding_arn": finding_arn, "sort_key": "STATE"},
                    ConsistentRead=True,
                ).get("Item", {})
                should_notify = existing.get("status") == "WAITING_APPROVAL" and not existing.get(
                    "notification_sent", False
                )
                if not should_notify:
                    ignored += 1
                    continue
                item = existing
                is_new = False
            else:
                raise

        if item.get("status") == "WAITING_APPROVAL" and item.get("notification_sent"):
            ignored += 1
            continue

        if is_new:
            audit(
                table,
                finding_arn,
                "FINDING_RECEIVED",
                "securityhub",
                {"control_id": resource["control_id"], "risk_score": score},
            )
        notifier.publish(
            TopicArn=os.environ["NOTIFICATION_TOPIC_ARN"],
            Subject=f"[{(finding.get('Severity') or {}).get('Label', 'UNKNOWN')}] "
            "AWS security finding requires approval",
            Message=json.dumps(
                {
                    "finding_arn": finding_arn,
                    "title": item["title"],
                    "control_id": resource["control_id"],
                    "resource_id": resource["resource_id"],
                    "risk_score": score,
                    "status": "WAITING_APPROVAL",
                    "instructions": "Review the finding, then use the IAM-authenticated "
                    "approval endpoint described in the project README.",
                }
            ),
        )
        table.update_item(
            Key={"finding_arn": finding_arn, "sort_key": "STATE"},
            UpdateExpression="SET notification_sent = :sent, updated_at = :now",
            ConditionExpression="#status = :pending",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":sent": True,
                ":now": utc_now(),
                ":pending": "WAITING_APPROVAL",
            },
        )
        audit(table, finding_arn, "APPROVAL_NOTIFICATION_SENT", "securityhub")
        accepted += 1

    return {"accepted": accepted, "ignored": ignored}
