terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_s3_bucket" "file_bucket" {
  bucket = "lambda-file-processor-1073e95a"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encrypt" {
  bucket = data.aws_s3_bucket.file_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "auto_cleanup" {
  bucket = data.aws_s3_bucket.file_bucket.id

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

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"

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
      Resource = "${data.aws_s3_bucket.file_bucket.arn}/*"
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

resource "aws_iam_role_policy" "ses_access" {
  name = "ses-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      Resource = "*"
    }]
  })
}

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
      Resource = "arn:aws:sns:${var.region}:${data.aws_caller_identity.current.account_id}:s3-file-upload-notifications"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = data.aws_s3_bucket.file_bucket.arn
        }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.uploads_notifications.arn
  protocol  = "email"
  endpoint  = var.ses_recipient_email
}

resource "aws_lambda_function" "file_processor" {
  filename      = var.lambda_zip
  function_name = "s3-file-processor-${random_id.suffix.hex}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      S3_BUCKET           = data.aws_s3_bucket.file_bucket.id
      SNS_TOPIC_ARN       = aws_sns_topic.uploads_notifications.arn
      SES_SENDER_EMAIL    = var.ses_sender_email
      SES_RECIPIENT_EMAIL = var.ses_recipient_email
      ALLOWED_ORIGIN      = var.allowed_origin
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
  source_arn    = data.aws_s3_bucket.file_bucket.arn
}

resource "aws_s3_bucket_notification" "lambda_event" {
  bucket = data.aws_s3_bucket.file_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.file_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "lambda/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_s3_bucket_notification" "sns_event" {
  bucket = data.aws_s3_bucket.file_bucket.id

  topic {
    topic_arn    = aws_sns_topic.uploads_notifications.arn
    events       = ["s3:ObjectCreated:*"]
    filter_prefix = "sns/"
  }
}

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
  rest_api_id             = aws_api_gateway_rest_api.file_api.id
  resource_id             = aws_api_gateway_method.proxy.resource_id
  http_method             = aws_api_gateway_method.proxy.http_method
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
          region   = var.region,
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
          region = var.region,
          title = "Recent Lambda Logs"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ses_send_email" {
  name = "ses-send-email"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "ses:SendEmail",
      Resource = "*"
    }]
  })
}

