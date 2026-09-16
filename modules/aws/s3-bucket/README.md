# s3-bucket

## What it creates

A single S3 bucket for general-purpose storage:

- `aws_s3_bucket` — the bucket itself.
- `aws_s3_bucket_versioning` — versioning, `Enabled` or `Suspended` depending on `versioning_enabled`.
- `aws_s3_bucket_server_side_encryption_configuration` — SSE-KMS, using the CMK passed in via `kms_key_arn`, with `bucket_key_enabled = true`.
- `aws_s3_bucket_public_access_block` — all four flags always on.

The module does not create the KMS key itself — the caller creates the CMK and passes its ARN in.

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | name of the s3 bucket to create | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | arn of the kms key used to encrypt objects in the bucket | `string` | n/a | yes |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | whether bucket versioning is enabled | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | n/a |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | n/a |

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15.9, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.64 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.64.0 |
<!-- END_TF_DOCS -->

## Daily cost

Per [docs/cost-model.md](../../../docs/cost-model.md), S3 is listed under "≈ nothing / Ignore" — so this module's own resources (bucket, versioning, encryption config, public access block) add roughly **$0/day**, storage and request costs aside.

The CMK used for encryption isn't created by this module, so its cost isn't counted here — per the cost model it's a fixed $1/mo (~$0.033/day) per key, billed against whichever stack creates it.

## Public access and encryption are not configurable

Public access is always blocked, and isn't tweakable using variables — this is strict policy of this project.

The same goes for encryption: it's always on, using a CMK — this is policy, not a preference, so there's no variable to disable it either.
