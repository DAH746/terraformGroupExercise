#we think this one xd
resource "aws_s3_bucket" "log-conts-ALB" {
    bucket = "Log-bucket-for-conts-ALB-3674"
    acl = "private"

 versioning {
    enabled = true
 }

 lifecycle_rule {
        id = "glacierLogs"
        prefix = "logs/"
        enabled = true

        transition {
            days = 30
            storage_class = "GLACIER"
        }

        expiration {
            days = 365
        }
    }
}
