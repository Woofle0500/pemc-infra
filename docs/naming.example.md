# Naming

## AWS

| Thing | Value | Notes |
|---|---|---|
| Management account | 730335219774 | account ID |
| Management account email | `<redacted>` | |
| Sandbox account | 782747473473 | account ID |
| Sandbox account email | `<redacted>` | |
| Root email pattern | `<redacted>+<account-name>@gmail.com` | Using plus addressing for root emails of managed accounts |
| SSO start URL | `<redacted>` | |
| Region | `ap-south-1` | |
| Permission Set | `PEMCAdmin` | Set name, with `AdministratorAccess` |
| CLI profiles | `management` and `sandbox` | Configured using SSO |
| S3 bucket prefix | `woofle-pemc` | globally unique |
| State bucket | `woofle-pemc-tfstate` | |
| Terraform run bucket | `woofle-pemc-tf-run` | Management account; holds per-run plan/apply artifacts, central across all provisioned accounts |
| Evidence bucket | `woofle-pemc-evidence` | Object Lock, pending |
| Canary bucket | `woofle-pemc-lp-canary` | Sandbox account; holds `canary.txt`, a known-existing key the least-privilege assertion probes against (see [plan-least-privilege.md](verification/plan-least-privilege.md)) |
| KMS key alias (state) | `alias/woofle-pemc-tfstate` | Management account; dedicated to the state bucket |
| KMS key alias (run) | `alias/woofle-pemc-tf-run` | Management account; dedicated to the Terraform run bucket |
| KMS key alias (sandbox) | `alias/woofle-pemc-s3` | Sandbox account; shared by the sandbox account's S3 buckets |
| CI role (plan, management) | `pemc-management-plan` | Management account; assumable from any pull request in this repo |
| CI role (apply, management) | `pemc-management-apply` | Management account; assumable only from the `sandbox-apply` GitHub Actions environment |
| SSM kill switch | `/pemc/kill-switch` | |
| SSM mode | `/pemc/mode` | |

## GCP

| Thing | Value | Notes |
|---|---|---|
| Region | `asia-south1` | |
| Org ID | `<redacted>` | |
| Project | | |

## Common

| Thing | Value | Notes |
|---|---|---|
| GitHub environment | `sandbox-apply` | |
| Tag prefix | `pemc:` | |
| Infrastructure Repo Name | `pemc-infra` | |
| Policy Repo Name | `pemc-policy` | |

## Tags

### Allowed values for `pemc:environment`
| Value | Applies to |
|---|---|
| `platform` | Shared infrastructure serving all environments — state bucket, Terraform run bucket, KMS key, OIDC provider, evidence bucket |
| `sandbox` | Workload resources in the sandbox account |
