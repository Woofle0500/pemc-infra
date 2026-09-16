variable "bucket_name" {
  type        = string
  description = "name of the s3 bucket to create"
}

variable "versioning_enabled" {
  type        = bool
  description = "whether bucket versioning is enabled"
  default     = true
}

variable "allow_public_access" {
  type        = bool
  description = "whether the bucket is allowed to be publicly accessible"
  default     = false
}

variable "encryption_enabled" {
  type        = bool
  description = "whether server-side encryption is enabled for the bucket"
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "arn of the kms key used to encrypt objects in the bucket; if not set, AWS defaults to the AWS-managed key (aws/s3)"
  default     = null
}
