import pytest
import json
from unittest.mock import Mock, patch
from lambda.lambda_function import lambda_handler

# Test successful file processing
@patch('lambda.lambda_function.sns')
@patch('lambda.lambda_function.logger')
def test_lambda_handler_success(mock_logger, mock_sns):
    # Mock S3 event
    event = {
        "Records": [{
            "s3": {
                "bucket": {"name": "test-bucket"},
                "object": {"key": "test.txt", "size": 1024}
            },
            "eventTime": "2024-01-01T00:00:00Z"
        }]
    }
    
    # Mock context
    context = Mock(aws_request_id="test-request-123")
    
    # Execute Lambda handler
    result = lambda_handler(event, context)
    
    # Verify results
    assert result['statusCode'] == 200
    mock_sns.publish.assert_called_once()
    mock_logger.info.assert_called()

# Test error handling
def test_lambda_handler_error():
    with pytest.raises(Exception):
        lambda_handler({"invalid": "event"}, None)