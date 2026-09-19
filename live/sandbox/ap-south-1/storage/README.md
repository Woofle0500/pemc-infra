# sandbox/ap-south-1/storage

## What it creates

Sandbox account storage in `ap-south-1`:

- `module.storage` ([modules/aws/s3-bucket](../../../../modules/aws/s3-bucket)) — the S3 bucket itself, with versioning enabled and encrypted using the shared sandbox S3 CMK. Public access blocking and SSE-KMS encryption are enforced unconditionally by that module, not by anything in this stack.

The CMK itself (`alias/woofle-pemc-s3`) is provisioned in [live/sandbox/_bootstrap](../../_bootstrap) — shared across sandbox S3 buckets rather than dedicated to this one — and looked up here via `data.aws_kms_alias.storage` rather than a hardcoded ARN.

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | n/a | `string` | `"woofle-pemc-sandbox-storage"` | no |
| <a name="input_kms_key_alias"></a> [kms\_key\_alias](#input\_kms\_key\_alias) | alias of the shared sandbox S3 CMK, provisioned in live/sandbox/\_bootstrap | `string` | `"alias/woofle-pemc-s3"` | no |
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

Per [docs/cost-model.md](../../../../docs/cost-model.md), the S3 bucket itself is listed under "≈ nothing / Ignore" — so this stack runs at roughly **$0/day**. The shared CMK's cost (fixed $1/mo + $0.000003/request) is billed against [live/sandbox/_bootstrap](../../_bootstrap), which creates it.

## Running it locally

This stack has a split credential requirement: its **state** lives in the management account's bucket, but the **resource** it provisions (the S3 bucket) lives in the sandbox account. So you need the management profile for the backend, and sandbox credentials active for the provider.

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

`terraform destroy` is the normal path, it removes the S3 bucket. The CMK (`alias/woofle-pemc-s3`) is destroyed, if ever, from [live/sandbox/_bootstrap](../../_bootstrap) instead — `pemc-apply`'s boundary scopes `DenyKmsKeyDestruction` to the state key only, so that stack's copy of this key can be destroyed. If it's ever orphaned outside of state, fall back to the [KMS CMK section of the teardown runbook](../../../../docs/teardown-runbook.md#6-kms-cmk) — but never schedule deletion for `alias/woofle-pemc-s3-shared`, only for `alias/woofle-pemc-s3`.

## State file

- Bucket: `woofle-pemc-tfstate`
- Key: `live/sandbox/ap-south-1/storage/terraform.tfstate`
- Region: `ap-south-1`

Same bucket/CMK as every other stack, in the management account.
