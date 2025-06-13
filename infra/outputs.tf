output "lambda_function_name" {
  value = aws_lambda_function.file_processor.function_name
}

output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.file_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/test"
}

output "sns_topic_arn" {
  value = aws_sns_topic.uploads_notifications.arn
}

