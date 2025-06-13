import os
import boto3
import json
import logging
import traceback
from datetime import datetime

# Initialize clients
s3 = boto3.client('s3')
sns = boto3.client('sns')

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
SNS_TOPIC_ARN = os.getenv('SNS_TOPIC_ARN')
ALLOWED_ORIGIN = os.getenv('ALLOWED_ORIGIN', '*')

def lambda_handler(event, context):
    headers = {
        'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key',
        'Access-Control-Allow-Methods': 'POST,OPTIONS',
        'Content-Type': 'application/json'
    }

    try:
        # Check if this is an API Gateway event (has httpMethod key)
        if 'httpMethod' in event:
            logger.info("API Gateway event received.")
            # You can process the event['body'] or other info here if needed
            body = event.get('body')
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'API Gateway call received',
                    'received_body': body
                }),
                'headers': headers
            }

        # Otherwise, assume this is an S3 event notification
        audit_log = {
            "event_time": datetime.utcnow().isoformat(),
            "aws_request_id": context.aws_request_id,
            "processed_files": []
        }

        for record in event.get('Records', []):
            # Defensive check that 's3' key exists (in case non-S3 event slips in)
            if 's3' not in record:
                logger.warning("Record without 's3' key encountered, skipping: " + json.dumps(record))
                continue

            file_info = {
                "bucket": record['s3']['bucket']['name'],
                "key": record['s3']['object']['key'],
                "size": record['s3']['object'].get('size', 'unknown'),
                "event_time": record['eventTime']
            }

            # Log file receipt
            logger.info(json.dumps({
                "action": "file_received",
                **file_info
            }))

            # Send notification if SNS topic ARN provided
            if SNS_TOPIC_ARN:
                sns_response = sns.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Message=json.dumps(file_info),
                    Subject='S3 Upload Notification'
                )
                logger.info(json.dumps({
                    "action": "notification_sent",
                    "sns_message_id": sns_response['MessageId']
                }))

            audit_log["processed_files"].append(file_info)

        return {
            'statusCode': 200,
            'body': json.dumps(audit_log),
            'headers': headers
        }

    except Exception as e:
        error_log = {
            "error": str(e),
            "stack_trace": traceback.format_exc(),
            "event": event
        }
        logger.error(json.dumps(error_log))

        return {
            'statusCode': 500,
            'body': json.dumps({"error": "File processing failed"}),
            'headers': headers
        }

