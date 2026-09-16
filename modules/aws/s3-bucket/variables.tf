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
