provider "aws" {
 region = "eu-west-2"
}

resource "aws_vpc" "prod-vpc" {
 cidr_block = "10.0.0.0/16"
}

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


resource "aws_security_group" "allow_http/s" {
  name        = "allow_http/s"
  description = "Allow HTTP/S inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress = [
    {
      description      = "HTTP/s from VPC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = aws_vpc.prod-vpc.cidr_block
    }
    {
      description      = "HTTP from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = aws_vpc.prod-vpc.cidr_block
  ]
   }
  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = [":
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
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
  security_groups    =
  subnets            =

  access_logs {
    bucket  = log-conts-ALB.bucket
    prefix  = "uk-alb-tf"
    enabled = true
  }

  tags = {
    Environment = "production"
  }




