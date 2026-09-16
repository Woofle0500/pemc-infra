# sandbox/ap-south-1/storage

## What it creates

Sandbox account storage in `ap-south-1`:

- `aws_kms_key.storage` / `aws_kms_alias.storage` — a dedicated CMK for this bucket, key rotation enabled.
- `module.storage` ([modules/aws/s3-bucket](../../../../modules/aws/s3-bucket)) — the S3 bucket itself, with versioning enabled and encrypted using the CMK above. Public access blocking and SSE-KMS encryption are enforced unconditionally by that module, not by anything in this stack.

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | n/a | `string` | `"woofle-pemc-sandbox-storage"` | no |
| <a name="input_kms_key_alias"></a> [kms\_key\_alias](#input\_kms\_key\_alias) | n/a | `string` | `"alias/woofle-pemc-s3"` | no |
| <a name="input_kms_key_description"></a> [kms\_key\_description](#input\_kms\_key\_description) | n/a | `string` | `"CMK for the sandbox storage s3 buckets"` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | n/a | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | n/a |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | n/a |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | n/a |

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.15.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.64 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.64.0 |
<!-- END_TF_DOCS -->

## Daily cost

Per [docs/cost-model.md](../../../../docs/cost-model.md):

- The CMK this stack creates: fixed $1/mo (~$0.033/day) + $0.000003 per request.
- The S3 bucket itself: listed under "≈ nothing / Ignore".

So this stack runs at roughly **$0.033/day**, driven entirely by the CMK — the bucket itself is free in practice.

## Running it locally

This stack has a split credential requirement: its **state** lives in the management account's bucket, but the **resources** it provisions (CMK, S3 bucket) live in the sandbox account. So you need the management profile for the backend, and sandbox credentials active for the provider.

```sh
export AWS_PROFILE=sandbox   # used by the aws provider to create resources

terraform init -backend-config="profile=<management-profile>"
terraform plan
terraform apply
```

### Tearing down

```sh
terraform destroy
```

`terraform destroy` is the normal path — `pemc-apply`'s boundary permits it, and the fix in [live/sandbox/_bootstrap](../../_bootstrap) scopes `DenyKmsKeyDestruction` to the state key only, so this stack's own CMK can be destroyed. If the CMK is ever orphaned outside of state (destroy fails, manual creation, etc.), fall back to the [KMS CMK section of the teardown runbook](../../../../docs/teardown-runbook.md#6-kms-cmk) — but never schedule deletion for `alias/woofle-pemc-tfstate`, only for `alias/woofle-pemc-s3` (this stack's key).

## State file

- Bucket: `woofle-pemc-tfstate`
- Key: `live/sandbox/ap-south-1/storage/terraform.tfstate`
- Region: `ap-south-1`

Same bucket/CMK as every other stack, in the management account.
