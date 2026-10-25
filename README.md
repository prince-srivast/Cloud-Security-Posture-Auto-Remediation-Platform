# Cloud Security Posture & Auto-Remediation Platform

An AWS single-account reference implementation for detecting selected cloud
misconfigurations, scoring findings, requiring an IAM-authenticated approval,
and applying a small allowlist of remediations. It is designed to be reviewed
and adapted before use in a production account.

## What it does

- Enables AWS Config recording and managed rules for public S3 access, SSH/RDP
  exposure, and security-group ports outside a configurable allowlist.
- Enables Security Hub and its AWS Foundational Security Best Practices standard.
- Routes active Security Hub findings to a Lambda intake function.
- Supports Security Hub controls `S3.1`, `S3.2`, `S3.3`, `EC2.13`, `EC2.14`,
  and `EC2.19`; unsupported or ambiguous findings are ignored.
- Assigns a deterministic 0–100 severity score and publishes approval notices
  through SNS.
- Provides a read-only, IAM-authenticated JSON compliance report with counts by
  control and workflow status, average risk score, and finding details.
- Requires an IAM-authenticated API call to approve or reject each finding.
- Only after approval, enables all four S3 Block Public Access settings or
  narrowly revokes world-open TCP SSH/RDP ports for `EC2.13`/`EC2.14` and
  exact non-authorized TCP rules for `EC2.19`. Rules spanning an allowed port
  or combining an admin port with other ports are left unchanged for review.
  Other source CIDRs are preserved; UDP and all-protocol rules are not changed.
- Stores workflow state and append-only action records in an encrypted,
  point-in-time-recoverable DynamoDB table.

The approval endpoint is not public/anonymous: API Gateway requires AWS IAM
request signing. Terraform creates an IAM policy that an account administrator
can attach only to selected operator roles. Subscribing an operator to the SNS
topic is a separate, explicit step.

## Important limitations

- This is a single-account, single-region starting point, not an Organizations
  deployment or a compliance certification.
- Security Hub must produce findings for the controls supported by the intake
  code. AWS Config and Security Hub findings can take time to appear after
  deployment.
- Remediation is intentionally narrow and can affect workloads: S3 public
  access blocking can break a public website, and removing world-open SSH/RDP
  or non-authorized TCP ingress can interrupt intended connectivity. Review the
  resource and change impact before approving.
- Terraform `prevent_destroy` guards protect the Config bucket and findings
  table from accidental destroy. Remove the guard only after an approved
  retention/export plan.
- The initial version does not generate downloadable compliance reports,
  support cross-account remediation, or automatically approve findings.
- The notification only reports a finding. It is not an approval link.

## Requirements

- Terraform 1.6+
- An AWS account and credentials authorized to create Config, Security Hub,
  Lambda, IAM, API Gateway, SNS, DynamoDB, EventBridge, and S3 resources
- Python 3.12 for local tests

Some AWS services may incur charges. Review service pricing and your
organization's account policies before deployment.

## Deploy

The root stack in `infra/` composes small child modules. Configure it using
`terraform.tfvars` or `-var` arguments; the root variables expose resource
names, AWS Config recording/rules, Security Hub enablement, DynamoDB retention,
Lambda runtime/timeouts, and API stage settings. For example:

```hcl
aws_region              = "us-east-1"
project_name            = "acme-posture"
authorized_tcp_ports    = "443,8443"
enable_config_recorder  = true
record_all_resources    = true
enable_security_hub     = true
enable_foundational_standard = true
lambda_runtime          = "python3.12"
api_stage_name          = "v1"
```

Do not add AWS credentials to `terraform.tfvars`; use an AWS profile, role, or
OIDC-based credentials supplied by your deployment environment.

From `infra/`:

```powershell
terraform init
terraform plan -var="aws_region=us-east-1"
terraform apply -var="aws_region=us-east-1"
```

Use a reviewed `terraform.tfvars` file or your normal secret-free deployment
pipeline for configuration; do not commit credentials or state files.

## Terraform modules

Each component has a focused input/output interface under `infra/modules/`:

| Module | Responsibility |
| --- | --- |
| `config_baseline` | Config recorder, protected delivery bucket, and configurable managed rules |
| `security_hub` | Optional Security Hub account and standards subscription |
| `findings_store` | Encrypted DynamoDB workflow and audit storage |
| `notifications` | SNS topic for review notifications |
| `lambda_workflow` | Packaged Lambda handlers, least-privilege roles, and EventBridge intake |
| `approval_api` | IAM-authorized approval and report endpoints |

The root stack is an example of composing these modules. They inherit the AWS
provider configuration from the caller and declare their required providers;
they can also be called separately from another Terraform root. Example:

```hcl
module "findings_store" {
  source = "git::https://github.com/OWNER/REPOSITORY.git//infra/modules/findings_store?ref=v1.0.0"

  table_name                  = "example-security-findings"
  point_in_time_recovery      = true
  deletion_protection_enabled = true
}
```

Replace `OWNER/REPOSITORY` and the tag with your public repository and a
reviewed release. Pin reusable modules to immutable tags or commit SHAs in
production. The Lambda module accepts a source directory and package path;
its source must contain the `cloud_guard` package used by the handlers.
`infra/moved.tf` preserves existing root-stack resource addresses when upgrading
an installation that used the original, pre-module Terraform layout.

Copy `infra/terraform.tfvars.example` to `infra/terraform.tfvars` and adjust
non-secret settings for a local deployment. Before upgrading an existing
installation, back up the Terraform state and inspect `terraform plan`; the
`moved` declarations are intended to retain resource identities, but provider
or configuration changes can still produce independent updates.

After apply:

1. Subscribe approved operators to the `notification_topic_arn` output and
   confirm the subscription.
2. Have an account administrator attach `approval_client_policy_arn` only to
   the IAM roles authorized to approve changes.
3. Attach `report_client_policy_arn` only to approved audit/report-reader roles.
4. Review the generated Config rules, Security Hub controls, IAM policies,
   CloudWatch logs, and the approval API in a non-production account.
5. Verify a supported finding and the rejection path before testing approval.

## Approve or reject

The API accepts a JSON body and must be called with AWS Signature Version 4
using credentials for an IAM principal allowed to invoke the endpoint:

```json
{"finding_arn":"arn:aws:securityhub:us-east-1:123456789012:subscription/...","decision":"approve"}
```

Use `decision: "reject"` to record a rejection without running remediation.
For example, a locally installed and configured `awscurl` can sign the request:

```powershell
awscurl --service execute-api -X POST `
  -H "Content-Type: application/json" `
  -d '{"finding_arn":"<finding-arn>","decision":"approve"}' `
  "<approval_endpoint>"
```

`<approval_endpoint>` is the `approval_endpoint` Terraform output. Treat
approval credentials as privileged; the approval policy permits invoking the
approval API, not direct Lambda invocation.

## Compliance report

Call the `compliance_report_endpoint` output using SigV4 credentials for a
principal with the separate `report_client_policy_arn` policy attached. The
endpoint returns a JSON snapshot of stored findings, risk scores, statuses,
and control totals. Reports are paginated (default 200 findings, maximum 500);
use the returned `pagination.next_token` as the `continuation_token` query
parameter to fetch the next page. Summary counts and average risk score apply
to the current page. The report is generated on demand and is not a regulatory
attestation or a historical point-in-time archive.

## Local development

```powershell
python -m pip install -e ".[dev]"
ruff check .
pytest
```

The tests cover risk scoring, supported resource extraction, and the exact
security-group CIDR revocations. They do not replace an AWS integration test.

## Repository safety

Do not commit AWS credentials, Terraform state/plans, generated Lambda
packages, or real account findings. Review all IAM changes and test in an
isolated AWS account before production use.
