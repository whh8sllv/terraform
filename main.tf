provider "aws" {
  alias                      = "localstack"
  region                     = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id = true
  skip_region_validation     = true
  s3_use_path_style          = true
  access_key                 = "test"
  secret_key                 = "test"
  
  endpoints {
    s3     = "http://localhost:4566"
    lambda = "http://localhost:4566"
    sns    = "http://localhost:4566"
    iam    = "http://localhost:4566"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_s3_bucket" "my_s3_start" {
  provider = aws.localstack
  bucket   = "my-s3-start"
}

resource "aws_s3_bucket" "my_s3_finish" {
  provider = aws.localstack
  bucket   = "my-s3-finish"
}

resource "aws_s3_bucket_acl" "my_s3_start_acl" {
  provider = aws.localstack
  bucket   = aws_s3_bucket.my_s3_start.id

  acl = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "my_s3_start_lifecycle" {
  provider = aws.localstack
  bucket   = aws_s3_bucket.my_s3_start.id

  rule {
    id     = "Move to Glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}

resource "aws_iam_role" "my_lambda_exec_role" {
  provider = aws.localstack
  name     = "my_lambda_exec_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_lambda_function" "my_s3_copy_lambda" {
  provider          = aws.localstack
  filename          = "lambda.zip"
  function_name     = "my-s3-copy-function"
  role              = aws_iam_role.my_lambda_exec_role.arn
  handler           = "lambda_function.lambda_handler"
  runtime           = "python3.8"
  source_code_hash  = filebase64sha256("lambda.zip")
}

resource "aws_lambda_permission" "my_allow_s3_event" {
  provider        = aws.localstack
  statement_id    = "AllowExecutionFromS3Bucket"
  action          = "lambda:InvokeFunction"
  function_name   = aws_lambda_function.my_s3_copy_lambda.function_name
  principal       = "s3.amazonaws.com"
  source_arn      = aws_s3_bucket.my_s3_start.arn
}

resource "aws_s3_bucket_notification" "my_s3_start_notification" {
  provider = aws.localstack
  bucket   = aws_s3_bucket.my_s3_start.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.my_s3_copy_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_sns_topic" "my_example_topic" {
  provider = aws.localstack
  name     = "my-example-topic"
}

resource "aws_sns_topic_subscription" "my_example_subscription" {
  provider  = aws.localstack
  topic_arn = aws_sns_topic.my_example_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.my_s3_copy_lambda.arn
}

resource "aws_s3_bucket_notification" "my_s3_start_notification_with_sns" {
  provider = aws.localstack
  bucket   = aws_s3_bucket.my_s3_start.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.my_s3_copy_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  topic {
    topic_arn = aws_sns_topic.my_example_topic.arn
    events    = ["s3:ObjectCreated:*"]
  }
}