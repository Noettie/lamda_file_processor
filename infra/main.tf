terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "petra-hs-terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}


# S3 Bucket Configuration
resource "aws_s3_bucket" "file_bucket" {
  bucket = "lambda-file-processor-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encrypt" {
  bucket = aws_s3_bucket.file_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "auto_cleanup" {
  bucket = aws_s3_bucket.file_bucket.id

  rule {
    id     = "delete-old-files"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "${aws_s3_bucket.file_bucket.arn}/*"
    }]
  })
}

resource "aws_iam_role_policy" "sns_publish" {
  name = "sns-publish"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.uploads_notifications.arn
    }]
  })
}

# SNS Topic and Subscription
resource "aws_sns_topic" "uploads_notifications" {
  name = "s3-file-upload-notifications"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action = "SNS:Publish"
      Resource = "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:s3-file-upload-notifications"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.file_bucket.arn
        }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.uploads_notifications.arn
  protocol  = "email"
  endpoint  = "thandonoe.ndlovu@gmail.com"  # replace with your actual email
}

# Lambda Function
resource "aws_lambda_function" "file_processor" {
  filename      = "lambda.zip" # your zip file with the lambda code
  function_name = "s3-file-processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.file_bucket.id
      SNS_TOPIC_ARN = aws_sns_topic.uploads_notifications.arn
    }
  }

  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.file_bucket.arn
}

# S3 Event Notifications - Lambda
resource "aws_s3_bucket_notification" "lambda_event" {
  bucket = aws_s3_bucket.file_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.file_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "lambda/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# S3 Event Notifications - SNS
resource "aws_s3_bucket_notification" "sns_event" {
  bucket = aws_s3_bucket.file_bucket.id

  topic {
    topic_arn    = aws_sns_topic.uploads_notifications.arn
    events       = ["s3:ObjectCreated:*"]
    filter_prefix = "sns/"
  }
}

# API Gateway (Optional if you want API for Lambda invocation)
resource "aws_api_gateway_rest_api" "file_api" {
  name = "file-processor-api"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.file_api.id
  parent_id   = aws_api_gateway_rest_api.file_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.file_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.file_api.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.file_processor.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.lambda]
  rest_api_id = aws_api_gateway_rest_api.file_api.id
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.file_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "LambdaFileProcessor-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x    = 0,
        y    = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/Lambda", "Invocations", "FunctionName", "s3-file-processor" ],
            [ ".", "Errors", ".", "." ],
            [ ".", "Throttles", ".", "." ]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = "us-east-1",
          title    = "Lambda Function: Invocations, Errors, Throttles",
          period   = 300
        }
      },
      {
        type = "log",
        x    = 0,
        y    = 7,
        width  = 24,
        height = 6,
        properties = {
          query = "SOURCE '/aws/lambda/s3-file-processor'",
          region = "us-east-1",
          title = "Recent Lambda Logs"
        }
      }
    ]
  })
}

variable "region" {
  default = "us-east-1"
}

output "api_url" {
  value = "https://${aws_api_gateway_rest_api.file_api.id}.execute-api.us-east-1.amazonaws.com/prod/"
}


