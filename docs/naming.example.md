# Naming

## AWS

| Thing | Value | Notes |
|---|---|---|
| Management account | `<redacted>` | account ID |
| Management account email | `<redacted>` | |
| Sandbox account | `<redacted>` | account ID |
| Sandbox account email | `<redacted>` | |
| Root email pattern | `<redacted>+<account-name>@gmail.com` | Using plus addressing for root emails of managed accounts |
| SSO IPV4 URL | `<redacted>` | |
| Region | `ap-south-1` | |
| Permission Set | `PEMCAdmin` | Set name, with `AdministratorAccess` |
| CLI profiles | `management` and `sandbox` | Configured using SSO |
| S3 bucket prefix | `woofle-pemc` | globally unique |
| State bucket | `woofle-pemc-tfstate` | |
| Evidence bucket | `woofle-pemc-evidence` | Object Lock, Step 3 |
| KMS key alias | `alias/woofle-pemc-tfstate` | |
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
