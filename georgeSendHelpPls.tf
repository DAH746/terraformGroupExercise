# THIS 
resource "aws_s3_bucket" "log-conts-ALB" {
    bucket = "Log-bucket-for-conts-ALB-3674"
    acl = "private"

    versioning {
        enabled = true
    }

    lifecycle_rule {
        id = "monthlyRotation"
        prefix = "logs/"
        enabled = true

        expiration {
            days = 30
        }
    }
}

resource "aws_s3_bucket" "glacierLogs" {
    bucket = "glacierLogs"
    acl = "private"
    lifecycle_rule {
        id = "glacierLogsIDYo"
        enabled = true
        prefix = "logs/"

        transition {
            days = 1
            storage_class = "GLACIER"
        }

        expiration {
            days = 365
        }
    }
}

# Send help pls aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
# OR
# THIS
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
