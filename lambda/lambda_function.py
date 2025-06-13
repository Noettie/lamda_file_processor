import os
import boto3
import json
import logging
import traceback
from datetime import datetime
import urllib.parse

# Initialize clients
s3 = boto3.client('s3')
sns = boto3.client('sns')
ses = boto3.client('ses')  # Add SES client

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
SNS_TOPIC_ARN = os.getenv('SNS_TOPIC_ARN')
ALLOWED_ORIGIN = os.getenv('ALLOWED_ORIGIN', '*')
SES_SENDER = os.getenv('SES_SENDER_EMAIL')       # e.g. noreply@yourdomain.com
SES_RECIPIENT = os.getenv('SES_RECIPIENT_EMAIL') # e.g. you@example.com

def handle_api_gateway(event, context):
    logger.info("Handling API Gateway event")
    return {
        'statusCode': 200,
        'body': json.dumps({'message': '✅ API Gateway test successful'}),
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key',
            'Access-Control-Allow-Methods': 'POST,OPTIONS'
        }
    }

def handle_s3_event(event, context):
    headers = {
        'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key',
        'Access-Control-Allow-Methods': 'POST,OPTIONS',
        'Content-Type': 'application/json'
    }

    try:
        audit_log = {
            "event_time": datetime.utcnow().isoformat(),
            "aws_request_id": context.aws_request_id,
            "processed_files": []
        }

        for record in event.get('Records', []):
            bucket = record['s3']['bucket']['name']
            key = urllib.parse.unquote_plus(record['s3']['object']['key'])
            size = record['s3']['object'].get('size', 'unknown')
            event_time = record['eventTime']

            file_info = {
                "bucket": bucket,
                "key": key,
                "size": size,
                "event_time": event_time
            }

            # Log file receipt
            logger.info(json.dumps({
                "action": "file_received",
                **file_info
            }))

            # Send SNS notification
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

            # Send custom email via SES
            if SES_SENDER and SES_RECIPIENT:
                subject = "🚀 New File Uploaded to S3"
                body = f"""
Hello,

A new file was uploaded to your S3 bucket.

🗂️ Bucket: {bucket}
📄 File: {key}
📦 Size: {size} bytes
🕒 Time: {event_time}

Best regards,
Your Automation System
"""
                ses.send_email(
                    Source=SES_SENDER,
                    Destination={'ToAddresses': [SES_RECIPIENT]},
                    Message={
                        'Subject': {'Data': subject},
                        'Body': {'Text': {'Data': body}}
                    }
                )
                logger.info(json.dumps({
                    "action": "email_sent",
                    "to": SES_RECIPIENT,
                    "subject": subject
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

def lambda_handler(event, context):
    if 'httpMethod' in event:
        return handle_api_gateway(event, context)
    else:
        return handle_s3_event(event, context)

