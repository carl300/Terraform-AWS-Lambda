terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

# --- Networking: use default VPC and its subnets ---

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


# --- Security group for EC2 (SSH only, demo) ---

resource "aws_security_group" "ec2_sg" {
  name        = "dr-sample-ec2-sg"
  description = "Allow SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # open for demo; tighten in real setups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Ubuntu AMI lookup (Ubuntu 24.04 LTS) ---

# --- Ubuntu 24.04 AMI via SSM Parameter (always up to date) ---

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ubuntu_ami.value]
  }
}


# --- Primary EC2 instance ---

resource "aws_instance" "primary" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = var.instance_name
    Role = "dr-primary"
  }
}

# --- IAM role for Lambda ---

resource "aws_iam_role" "lambda_role" {
  name = "dr-ami-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "dr-ami-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateImage",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:CopyImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


# --- Package Lambda code into ZIP ---

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/create_and_copy_ami.py"
  output_path = "${path.module}/lambda/create_and_copy_ami.zip"
}

# --- Lambda function: create AMI + copy to DR region ---

resource "aws_lambda_function" "create_and_copy_ami" {
  function_name = "dr-create-and-copy-ami"
  role          = aws_iam_role.lambda_role.arn
  handler       = "create_and_copy_ami.lambda_handler"
  runtime       = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout = 300

  environment {
    variables = {
      INSTANCE_ID = aws_instance.primary.id
      DR_REGION   = var.dr_region
    }
  }
}


# --- EventBridge rule to schedule Lambda ---

resource "aws_cloudwatch_event_rule" "daily_ami" {
  name                = "dr-daily-ami-rule"
  schedule_expression = var.schedule_expression
}


resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_ami.name
  target_id = "dr-ami-lambda"
  arn       = aws_lambda_function.create_and_copy_ami.arn
}


resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_and_copy_ami.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_ami.arn
}
