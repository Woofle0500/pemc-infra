variable "bucket_name" {
  type        = string
  description = "name of the s3 bucket to create"
}

variable "versioning_enabled" {
  type        = bool
  description = "whether bucket versioning is enabled"
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "arn of the kms key used to encrypt objects in the bucket"
}
