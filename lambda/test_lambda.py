import json
import os
from lambda_function import lambda_handler  # adjust filename if needed

# Mock Lambda Context class
class LambdaContextMock:
    def __init__(self):
        self.aws_request_id = "test-request-id"

def load_event(filename):
    with open(filename, 'r') as f:
        return json.load(f)

if __name__ == "__main__":
    # Set environment variables (if needed)
    os.environ['SNS_TOPIC_ARN'] = 'arn:aws:sns:us-east-1:123456789012:your-topic'
    os.environ['SES_SENDER_EMAIL'] = 'noreply@yourdomain.com'
    os.environ['SES_RECIPIENT_EMAIL'] = 'you@example.com'
    os.environ['ALLOWED_ORIGIN'] = '*'

    context = LambdaContextMock()

    # Load API Gateway event and test
    api_event = load_event('api_gateway_event.json')
    print("=== Testing API Gateway event ===")
    response = lambda_handler(api_event, context)
    print(json.dumps(response, indent=2))

    # Load S3 event and test
    s3_event = load_event('s3_event.json')
    print("\n=== Testing S3 event ===")
    response = lambda_handler(s3_event, context)
    print(json.dumps(response, indent=2))

