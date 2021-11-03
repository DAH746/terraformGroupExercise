provider "aws" {
 region = "eu-west-2"
}

resource "aws_vpc" "prod-vpc" {
 cidr_block = "10.0.0.0/16"
} //todo subnets

resource "aws_subnet" "publicSubnet" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "publicSubnet"
  }
}
// START - Private subnets with respective AZs
resource "aws_subnet" "privateSubnetAZ2" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "privateSubnet"
  }

  availability_zone_id = "euw2-az2"
}

resource "aws_subnet" "privateSubnetAZ3" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "privateSubnet"
  }

  availability_zone_id = "euw2-az3"
}

resource "aws_subnet" "privateSubnetAZ1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "privateSubnet"
  }

  availability_zone_id = "euw2-az1"
}

//END - Private subnets with respective AZs

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

resource "aws_s3_bucket" "dev-bucket" {
 bucket = "dev-bucket-update-conts-code-3674"
 acl = "private"

 versioning {
  enabled = true
 }
}

resource "aws_internet_gateway" "gw" {
        vpc_id = aws_vpc.prod-vpc.id
}

// WAF - FIREWALL
resource "aws_wafregional_geo_match_set" "WAF-regional-UK" {
  name = "geo_match_set"

  geo_match_constraint {
    type  = "Country"
    value = "UK"
  }
}

resource "aws_security_group" "allow_https" {
  name        = "allow_http/s"
  description = "Allow HTTP/S inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress = [
    {
      description      = "HTTP/s from VPC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = [aws_vpc.prod-vpc.cidr_block]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    },
    {
      description      = "HTTP from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = [aws_vpc.prod-vpc.cidr_block]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]
  egress = [
      {
      description  = "Allowed in"
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
      }
  ]

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_lb" "uk-alb" {
  name               = "uk-alb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_https.id]
  subnets            = aws_subnet.publicSubnet.*.id

  access_logs {
    bucket  = aws_s3_bucket.log-conts-ALB.bucket
    prefix  = "uk-alb-tf"
    enabled = true
  }

  tags = {
    Environment = "production"
  }
}

// ECS

resource "aws_ecs_cluster" "ECS_cluster" {
  name = "tf-ecs-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_cloudwatch_logger" {
  name = "ecs_cloudwatch_logger"
}

resource "aws_ecs_task_definition" "task_definition" {
  family = "worker"
  container_definitions = jsonencode(
    [
      {
        essential: true,
        memory: 512,
        name: "worker",
        cpu: 2,
        image: "https://hub.docker.com/r/ubuntu/apache2:latest",
        environment: [],
        // Test start
        logConfiguration : {
          // https://aws.amazon.com/blogs/compute/centralized-container-logs-with-amazon-ecs-and-amazon-cloudwatch-logs/

          logDriver: "awslogs",
          options: {
            awslogs-group: "awslogs",
            awslogs-region: "eu-west-2",
            awslogs-stream-prefix: "ecs",
            cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_cloudwatch_logger.name
          }
        }
      },
    ]
  )
}

resource "aws_ecs_service" "main" {
  name            = "staging"
  cluster         = aws_ecs_cluster.ECS_cluster.id
  task_definition = aws_ecs_task_definition.task_definition.container_definitions
  desired_count   = 1
  launch_type     = "FARGATE"

//  load_balancer {
//    target_group_arn = aws_lb_target_group.staging.arn
//    container_name   = "sproutlyapi"
//    container_port   = 4000
//  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [euw2-az1, euw2-az2, euw2-az3]"
  }

  tags = {
    Environment = "staging"
    Application = "webApp"
  }
}

resource "aws_efs_file_system" "efsFor" {
  creation_token = "efs-FOR-ALL"

  tags = {
    Name = "efs"
  }
}

// Connect to EFS with mount points
resource "aws_efs_mount_target" "main1" {
  file_system_id = aws_efs_file_system.efsFor.id
  subnet_id = aws_subnet.privateSubnetAZ1.id
}
resource "aws_efs_mount_target" "main2" {
  file_system_id = aws_efs_file_system.efsFor.id
  subnet_id = aws_subnet.privateSubnetAZ2.id
}
resource "aws_efs_mount_target" "main3" {
  file_system_id = aws_efs_file_system.efsFor.id
  subnet_id = aws_subnet.privateSubnetAZ3.id
}

module "cluster" {
  source  = "terraform-aws-modules/rds-aurora/aws"

  name           = "test-aurora-db-postgres96"
  engine         = "aurora-postgresql"
  engine_version = "11.12"
  instance_class = "db.t2.micro"
  instances = {
    one = {}
    2 = {
      instance_class = "db.t2.micro"
    }
  }

  vpc_id  = aws_vpc.prod-vpc.id
  subnets = ["aws_subnet.privateSubnetAZ1", "aws_subnet.privateSubnetAZ2", "aws_subnet.privateSubnetAZ3"]

  storage_encrypted   = true
  apply_immediately   = true
  monitoring_interval = 10

  db_parameter_group_name         = "default"
  db_cluster_parameter_group_name = "default"

  engine_mode = "multimaster"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

module "aws_cli_terra" {
  source            = "digitickets/cli/aws"
  role_session_name = "GettingDesiredCapacityFor"
  aws_cli_commands  = ["create-deployment", "delete-deployment-config", "get-deployment-config", "list-deployments", "stop-deployment"]
}

 // Code pipeline stuff

resource "aws_iam_role" "pipeline_role" {
  name = "pipeline_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

 //https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.pipeline_role.id
  policy = jsonencode(
  {
    Version: "2012-10-17",
    "Statement": [
      {
        Effect:"Allow",
        Action: [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ],
        Resource: [
          "aws_s3_bucket.dev-bucket.bucket",
          "aws_s3_bucket.dev-bucket.arn/*"
        ]
      },
      {
        Effect: "Allow",
        Action: [
          "codestar-connections:UseConnection"
        ],
//        Resource: "${aws_codestarconnections_connection.example.arn}" // FIX
        Resource: "arn:aws:codestar-connections:us-west-2:connection/aEXAMPLE-8aad-4d5d-8878-dfcab0bc441f"
      },
      {
        Effect: "Allow",
        Action: [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        Resource: "*"
      }
    ]
  })
}

resource "aws_codepipeline" "codepipeline" {
  name = "tf-test-pipeline"

  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.dev-bucket.bucket
    type = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "arn:aws:codestar-connections:us-west-2:connection/aEXAMPLE-8aad-4d5d-8878-dfcab0bc441f"
        FullRepositoryId = "my-organization/example"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "test"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ActionMode     = "REPLACE_ON_FAILURE"
        Capabilities   = "CAPABILITY_AUTO_EXPAND,CAPABILITY_IAM"
        OutputFileName = "CreateStackOutput.json"
        StackName      = "MyStack"
        TemplatePath   = "build_output::sam-templated.yaml"
      }
    }
  }
}

module "codecommit" {

  source = "lgallard/codecommit/aws" // for module

  repository_name = "codecommit-repo"
  description     = "Git repository in AWS"
  default_branch  = "master"


  triggers = [
    {
      name            = "all"
      events          = ["all"]
      destination_arn = "arn:aws:lambda:eu-west-2:12345678910:function:lambda-all"
    },
    {
      name            = "updateReference"
      events          = ["updateReference"]
      destination_arn = "arn:aws:lambda:eu-west-2:12345678910:function:lambda-updateReference"
    },
  ]

  tags = {
    Owner       = "The georgeContinue team"
    Environment = "dev"
    Terraform   = true
  }

}

resource "aws_iam_role" "iam_role_for_codeBuild" {
  assume_role_policy = jsonencode({
  Version: "2012-10-17",
  Statement: [
    {
      Effect: "Allow",
      Principal: {
        Service: "codebuild.amazonaws.com"
      },
      Action: "sts:AssumeRole"
    }
  ]
  }
  )
}

resource "aws_codebuild_project" "codeBuilder" {
  name          = "test-project"
  description   = "test_codebuild_project"
  build_timeout = "5"
  service_role  = aws_iam_role.iam_role_for_codeBuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "env_1"
      value = "value_env_1"
    }

    environment_variable {
      name  = "env_2"
      value = "value_env_2"
      type  = "PARAMETER_STORE"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }

  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/mitchellh/packer.git"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }
  source_version = "master"

  tags = {
    Environment = "codebuild"
  }
}

// ---- LAST PLAN TEST ABOVE ---


//-----------------------------------------------------------
// FOLLOWING IS NOT FUNCTIONAL:
//      Attempts were made to provision the following services but could not be achieved.
//          - CLOUDFRONT
//          - ROUTE 53

// >> CLOUDFRONT <<

//resource "aws_cloudfront_distribution" "s3_distribution" {
//  origin {
//    domain_name = aws_s3_bucket.b.bucket_regional_domain_name
//    origin_id   = local.s3_origin_id
//
//    s3_origin_config {
//      origin_access_identity = "origin-access-identity/cloudfront/ABCDEFG1234567"
//    }
//  }
//
//  enabled             = true
//  is_ipv6_enabled     = true
//  comment             = "Some comment"
//  default_root_object = "index.html"
//
//  logging_config {
//    include_cookies = false
//    bucket          = "mylogs.s3.amazonaws.com"
//    prefix          = "myprefix"
//  }
//
//  aliases = ["mysite.example.com", "yoursite.example.com"]
//
//  default_cache_behavior {
//    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
//    cached_methods   = ["GET", "HEAD"]
//    target_origin_id = local.s3_origin_id
//
//    forwarded_values {
//      query_string = false
//
//      cookies {
//        forward = "none"
//      }
//    }
//
//    viewer_protocol_policy = "allow-all"
//    min_ttl                = 0
//    default_ttl            = 3600
//    max_ttl                = 86400
//  }
//
//  # Cache behavior with precedence 0
//  ordered_cache_behavior {
//    path_pattern     = "/content/immutable/*"
//    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
//    cached_methods   = ["GET", "HEAD", "OPTIONS"]
//    target_origin_id = local.s3_origin_id
//
//    forwarded_values {
//      query_string = false
//      headers      = ["Origin"]
//
//      cookies {
//        forward = "none"
//      }
//    }
//
//    min_ttl                = 0
//    default_ttl            = 86400
//    max_ttl                = 31536000
//    compress               = true
//    viewer_protocol_policy = "redirect-to-https"
//  }
//
//  # Cache behavior with precedence 1
//  ordered_cache_behavior {
//    path_pattern     = "/content/*"
//    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
//    cached_methods   = ["GET", "HEAD"]
//    target_origin_id = local.s3_origin_id
//
//    forwarded_values {
//      query_string = false
//
//      cookies {
//        forward = "none"
//      }
//    }
//
//    min_ttl                = 0
//    default_ttl            = 3600
//    max_ttl                = 86400
//    compress               = true
//    viewer_protocol_policy = "redirect-to-https"
//  }
//
//  price_class = "PriceClass_200"
//
//  restrictions {
//    geo_restriction {
//      restriction_type = "whitelist"
//      locations        = ["US", "CA", "GB", "DE"]
//    }
//  }
//
//  tags = {
//    Environment = "production"
//  }
//
//  viewer_certificate {
//    cloudfront_default_certificate = true
//  }
//}

// >> ROUTE 53 <<

//resource "aws_route53_record" "www-dev" {
//  zone_id = aws_route53_zone.primary.zone_id
//  name    = "www"
//  type    = "CNAME"
//  ttl     = "5"
//
//  weighted_routing_policy {
//    weight = 10
//  }
//
//  set_identifier = "dev"
//  records        = ["dev.example.com"]
//}
//
//resource "aws_route53_record" "www-live" {
//  zone_id = aws_route53_zone.primary.zone_id
//  name    = "www"
//  type    = "CNAME"
//  ttl     = "5"
//
//  weighted_routing_policy {
//    weight = 90
//  }
//
//  set_identifier = "live"
//  records        = ["live.example.com"]
//}
