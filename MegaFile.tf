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
      },

//      logConfiguration [{
//        // https://aws.amazon.com/blogs/compute/centralized-container-logs-with-amazon-ecs-and-amazon-cloudwatch-logs/
//        logDriver: "awslogs",
//        options: {
//          awslogs-group: "awslogs-test",
//          awslogs-region: "us-west-2",
//          awslogs-stream-prefix: "ecs"
//        }
//      }]
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

// ---- LAST PLAN TEST ABOVE ---

