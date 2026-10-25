from cloud_guard.policy import (
    public_ingress_permissions,
    risk_score,
    supported_finding,
)
from cloud_guard.report import build_report


def test_risk_score_is_bounded_and_control_aware():
    assert risk_score({"Label": "CRITICAL"}, "EC2.19") == 100
    assert risk_score({"Label": "MEDIUM"}, "S3.1") == 50
    assert risk_score({"Label": "unknown"}, "unknown") == 5


def test_supported_finding_extracts_one_s3_bucket():
    finding = {
        "Compliance": {"SecurityControlId": "S3.2"},
        "Resources": [{"Type": "AwsS3Bucket", "Id": "arn:aws:s3:::example-bucket"}],
    }
    assert supported_finding(finding) == {
        "control_id": "S3.2",
        "resource_type": "s3",
        "resource_id": "example-bucket",
    }


def test_unsupported_or_ambiguous_findings_are_ignored():
    assert supported_finding({"Compliance": {}, "Resources": []}) is None
    assert (
        supported_finding(
            {
                "Compliance": {"SecurityControlId": "S3.2"},
                "Resources": [
                    {"Type": "AwsS3Bucket", "Id": "bucket-one"},
                    {"Type": "AwsS3Bucket", "Id": "bucket-two"},
                ],
            }
        )
        is None
    )


def test_ssh_control_revokes_only_world_open_ssh_and_rdp_from_ipv4():
    permissions = [
        {
            "IpProtocol": "tcp",
            "FromPort": 22,
            "ToPort": 22,
            "IpRanges": [
                {"CidrIp": "0.0.0.0/0"},
                {"CidrIp": "10.0.0.0/8"},
            ],
            "Ipv6Ranges": [{"CidrIpv6": "::/0"}],
        }
    ]
    assert public_ingress_permissions(permissions, "EC2.13", {80, 443}) == [
        {
            "IpProtocol": "tcp",
            "FromPort": 22,
            "ToPort": 22,
            "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
        }
    ]


def test_ipv6_remote_admin_control_only_revokes_exact_admin_port_rules():
    assert public_ingress_permissions(
        [
            {
                "IpProtocol": "tcp",
                "FromPort": 22,
                "ToPort": 22,
                "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
                "Ipv6Ranges": [{"CidrIpv6": "::/0"}],
            },
            {
                "IpProtocol": "tcp",
                "FromPort": 20,
                "ToPort": 3400,
                "Ipv6Ranges": [{"CidrIpv6": "::/0"}],
            },
            {
                "IpProtocol": "tcp",
                "FromPort": 3389,
                "ToPort": 3389,
                "Ipv6Ranges": [{"CidrIpv6": "::/0"}],
            },
        ],
        "EC2.14",
        {80, 443},
    ) == [
        {
            "IpProtocol": "tcp",
            "FromPort": 22,
            "ToPort": 22,
            "Ipv6Ranges": [{"CidrIpv6": "::/0"}],
        },
        {
            "IpProtocol": "tcp",
            "FromPort": 3389,
            "ToPort": 3389,
            "Ipv6Ranges": [{"CidrIpv6": "::/0"}],
        },
    ]


def test_security_group_remediation_preserves_allowed_ports_and_other_protocols():
    assert public_ingress_permissions(
        [
            {"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]},
            {
                "IpProtocol": "udp",
                "FromPort": 53,
                "ToPort": 53,
                "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
            },
            {
                "IpProtocol": "tcp",
                "FromPort": 1,
                "ToPort": 65535,
                "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
            },
            {
                "IpProtocol": "tcp",
                "FromPort": 8080,
                "ToPort": 8080,
                "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
            },
        ],
        "EC2.19",
        {80, 443},
    ) == [
        {
            "IpProtocol": "tcp",
            "FromPort": 8080,
            "ToPort": 8080,
            "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
        },
    ]


def test_compliance_report_summarizes_status_and_risk():
    report = build_report(
        [
            {"finding_arn": "b", "control_id": "S3.2", "status": "REMEDIATED", "risk_score": 90},
            {
                "finding_arn": "a",
                "control_id": "EC2.13",
                "status": "WAITING_APPROVAL",
                "risk_score": 70,
            },
        ],
        "2026-10-25T00:00:00+00:00",
    )

    assert report["summary"] == {
        "total_findings": 2,
        "average_risk_score": 80,
        "by_control": {"EC2.13": 1, "S3.2": 1},
        "by_status": {"REMEDIATED": 1, "WAITING_APPROVAL": 1},
    }
    assert [finding["finding_arn"] for finding in report["findings"]] == ["a", "b"]


def test_empty_compliance_report_has_zero_average():
    report = build_report([], "2026-10-25T00:00:00+00:00")

    assert report["summary"]["total_findings"] == 0
    assert report["summary"]["average_risk_score"] == 0
