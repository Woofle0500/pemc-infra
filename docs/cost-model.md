# Cost model
| Thing | Rough cost | Risk |
|---|---|---|
| **NAT Gateway** | ~$0.056/hour each + $0.056 per-GB processed | **Highest.** One forgotten gateway is the whole budget |
| **EBS** | $0.0912/GB-month, with 3000 free IOPS and 125 MBps free Throughput | EBS keeps costing money whether it's attached or not. Unattached EBS volumes are the single most likely fixture in this project. |
| **AWS Config** | $0.003 or $0.012 Per configuration item + ≈$0.001 per rule evaluation | Scales with churn, not intent. Bears on the Part 5 decision |
| **Interface VPC endpoints** | $0.013/hour each, per AZ + $0.01 per-GB processed for first 1 PB | Adds up per service per AZ |
| **EC2 fixtures left running** | $0.0112/Hour per `t3.micro` + fixed $0.005 per public IPV4 per hour (elastic or not) | Individually small, but `fixtures/` exists to create deliberately broken resources — exactly what gets forgotten |
| **Terratest leaks** | Variable | §13.2 prescribes the sweeper. Build it *before* the first Terratest run |
| **KMS CMK** | fixed $1/mo per key + $0.000003 per requests | Predictable |
| **S3, CloudTrail management events, drift plan API calls, Actions minutes (public repo)** | ≈ nothing | Ignore |

## Notes
Almost everything expensive is hourly billed. Leaving them running will keep pilling up the cost. This doesn't mean that you don't run things; this means that ones you are don't using the things, don't leave them running and clean them up. Refer to [teardown-runbook](teardown-runbook.md) for cleaning up.

Among the services/resources provisioned in the multi-cloud infrastructure, only the things belonging to AWS are charged since the specific services provisioned in GCP don't cost anything.

AWS Budgets and Cost Anomaly Detection act as lagging nets: they notify us when spending exceeds a threshold or deviates from expected patterns, but they do not automatically stop cost growth by default. Monthly budgets track spending within each budget period, so the actual amount resets at the start of a new month rather than accumulating indefinitely. Review Cost Explorer weekly to identify cumulative spending, unexpected cost trends, and charges that may have gone unnoticed by the alerts.

In AWS, SCPs (Service Control Policies) are the main guardrail for the cost control. For example, denying NATGateway creation in the sandbox accounts, limit EC2 instance types to a select few so that only allowed instance types are provisioned, restricting regions etc - all this so that nothing expensive gets created. Budgets and cost anomaly is detection, SCPs are the prevention mechanisms located at the API request level.

In case where Terratest leaves orphaned resources, they are cleaned up by the Terratest sweeper.

