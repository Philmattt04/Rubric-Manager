output "cloudfront_domain" {
  description = "CloudFront distribution domain (useful before DNS propagates)"
  value       = aws_cloudfront_distribution.web.domain_name
}

output "cloudfront_id" {
  description = "CloudFront distribution ID (needed to invalidate cache after deploys)"
  value       = aws_cloudfront_distribution.web.id
}

output "s3_bucket" {
  description = "S3 bucket that holds the Flutter web build"
  value       = aws_s3_bucket.web.bucket
}

output "app_url" {
  description = "Live app URL"
  value       = "https://${var.domain}"
}
