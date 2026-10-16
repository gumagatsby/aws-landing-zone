output "trail_arn" {
  value = aws_cloudtrail.org.arn
}

output "log_bucket" {
  value = aws_s3_bucket.trail.id
}
