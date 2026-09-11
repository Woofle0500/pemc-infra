| Thing | Value | Notes |
|---|---|---|
| AWS management account | <management-account-id> | account ID |
| AWS sandbox account | | Step 2 |
| Root email pattern | | |
| AWS region | `ap-south-1` | |
| GCP region | `asia-south1` | |
| GCP org ID | <gcp-organisation-id> | |
| GCP project | | |
| S3 bucket prefix | `woofle-pemc` | globally unique |
| State bucket | `woofle-pemc-tfstate` | |
| Evidence bucket | `woofle-pemc-evidence` | Object Lock, Step 3 |
| KMS key alias | `alias/woofle-pemc-tfstate` | |
| GitHub environment | `sandbox-apply` | |
| SSM kill switch | `/pemc/kill-switch` | |
| SSM mode | `/pemc/mode` | |
| Tag prefix | `pemc:` | |
| Infrastructure Repo Name | `pemc-infra` | |
| Policy Repo Name | `pemc-policy` | |
