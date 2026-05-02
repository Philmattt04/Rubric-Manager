variable "domain" {
  description = "Full subdomain to serve the app on"
  default     = "rubriques.gwoupbousol.org"
}

variable "root_domain" {
  description = "Root domain for Route53 hosted zone lookup"
  default     = "gwoupbousol.org"
}

variable "bucket_name" {
  description = "S3 bucket name for Flutter web app assets"
  default     = "rubriques-gwoupbousol-org"
}
