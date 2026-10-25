"""Allowlisted AWS resource remediation Lambda."""

from __future__ import annotations

import os
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from cloud_guard.policy import public_ingress_permissions
from cloud_guard.storage import audit, utc_now


def _set_status(table: Any, finding_arn: str, status: str) -> None:
    table.update_item(
        Key={"finding_arn": finding_arn, "sort_key": "STATE"},
        UpdateExpression="SET #status = :status, updated_at = :now",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={":status": status, ":now": utc_now()},
    )


def handler(event: dict[str, Any], _context: Any) -> dict[str, str]:
    finding_arn = event.get("finding_arn")
    if not isinstance(finding_arn, str):
        raise TypeError("finding_arn is required")

    table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    result = table.get_item(
        Key={"finding_arn": finding_arn, "sort_key": "STATE"},
        ConsistentRead=True,
    ).get("Item")
    if not result or result.get("status") != "APPROVED":
        raise ValueError("Finding must exist and be approved before remediation")

    response = table.update_item(
        Key={"finding_arn": finding_arn, "sort_key": "STATE"},
        UpdateExpression="SET #status = :running, updated_at = :now",
        ConditionExpression="#status = :approved",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":running": "REMEDIATING",
            ":approved": "APPROVED",
            ":now": utc_now(),
        },
        ReturnValues="ALL_NEW",
    )
    state = response["Attributes"]
    audit(table, finding_arn, "REMEDIATION_STARTED", "remediator")

    try:
        account_id = boto3.client("sts").get_caller_identity()["Account"]
        if state.get("account_id") != account_id:
            raise ValueError("Finding account does not match the remediation account")
        region = state["region"]
        resource_id = state["resource_id"]
        control_id = state["control_id"]
        if state["resource_type"] == "s3" and control_id in {"S3.1", "S3.2", "S3.3"}:
            boto3.client("s3", region_name=state["region"]).put_public_access_block(
                Bucket=resource_id,
                PublicAccessBlockConfiguration={
                    "BlockPublicAcls": True,
                    "IgnorePublicAcls": True,
                    "BlockPublicPolicy": True,
                    "RestrictPublicBuckets": True,
                },
            )
        elif state["resource_type"] == "security-group" and control_id in {
            "EC2.13",
            "EC2.14",
            "EC2.19",
        }:
            ec2 = boto3.client("ec2", region_name=region)
            groups = ec2.describe_security_groups(GroupIds=[resource_id]).get("SecurityGroups", [])
            if len(groups) != 1:
                raise ValueError("Expected exactly one security group")
            authorized_tcp_ports = {
                int(port) for port in os.environ["AUTHORIZED_TCP_PORTS"].split(",")
            }
            revocations = public_ingress_permissions(
                groups[0].get("IpPermissions", []),
                control_id,
                authorized_tcp_ports,
            )
            if not revocations:
                raise ValueError("No safely matching world-open ingress rules remain")
            for permission in revocations:
                ec2.revoke_security_group_ingress(
                    GroupId=resource_id,
                    IpPermissions=[permission],
                )
        else:
            raise ValueError("Finding is outside the remediation allowlist")
    except (BotoCoreError, ClientError, ValueError):
        _set_status(table, finding_arn, "FAILED")
        audit(table, finding_arn, "REMEDIATION_FAILED", "remediator")
        raise

    _set_status(table, finding_arn, "REMEDIATED")
    audit(table, finding_arn, "REMEDIATION_SUCCEEDED", "remediator")
    return {"status": "REMEDIATED"}
