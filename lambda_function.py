import json
import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Handle S3 trigger events
    if 'Records' in event and event['Records'][0]['eventSource'] == 'aws:s3':
        return handle_s3_event(event)
   
    # Handle API Gateway requests
    return handle_api_request(event)

def handle_s3_event(event):
    """Process S3 file upload events"""
    try:
        record = event['Records'][0]['s3']
        bucket = record['bucket']['name']
        key = record['object']['key']
       
        print(f"New file uploaded: {key} to bucket {bucket}")
       
        # Example processing:
        # 1. Get file metadata
        response = s3.head_object(Bucket=bucket, Key=key)
        file_size = response['ContentLength']
        content_type = response['ContentType']
       
        # 2. You could process the file here (e.g., transform, analyze, etc.)
        # For example, let's just log some details
        result = {
            'status': 'processed',
            'bucket': bucket,
            'key': key,
            'size': file_size,
            'type': content_type,
            'message': 'File successfully processed'
        }
       
        # 3. You could write results to DynamoDB, send SNS notification, etc.
       
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
       
    except Exception as e:
        print(f"Error processing S3 event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def handle_api_request(event):
    """Handle direct API Gateway requests"""
    try:
        # Get query parameters if they exist
        query_params = event.get('queryStringParameters', {})
        name = query_params.get('name', 'World')
       
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'message': f'Hello {name} from Lambda!',
                'usage': {
                    's3_upload': f'Upload files to S3 bucket {os.environ.get("BUCKET_NAME")} to trigger processing',
                    'api_parameters': 'Add ?name=YourName to personalize the response'
                }
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
