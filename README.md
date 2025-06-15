# 📁 Petra High School File Processing System

This project is a **serverless file processing system** built on AWS for Petra High School. It allows teachers to upload student marksheets (scripts) to an S3 bucket, which automatically triggers a Lambda function to process the files and send notifications.

The solution ensures:
- Automation of file intake.
- Immediate processing and logging of uploads.
- Email notifications to subscribed staff via SNS.
- Scalability using AWS-managed services.

---

## 🧠 Project Goal

To design and deploy an automated backend system that:
- Accepts marks uploads via S3.
- Logs and processes each uploaded script.
- Notifies relevant teachers or administrators when uploads are completed.
- Is secure, scalable, and easy to maintain.

---

## ⚙️ Architecture Overview

**AWS Services Used:**
- **S3** – Storage for student scripts.
- **Lambda** – Triggered when a file is uploaded; processes and logs the file.
- **SNS (Simple Notification Service)** – Sends email alerts for every processed file.
- **API Gateway** – Optional REST interface to trigger the Lambda or check health.
- **IAM** – Manages permissions securely.
- **Terraform** – Infrastructure as code (IaC) to deploy and manage all resources.
- **Jenkins** – CI/CD pipeline automates deployment from source to production.

---

## 📂 Project Structure

Set up AWS credentials in Jenkins or environment.

Configure the variables.tf file as needed.

Trigger Jenkins pipeline or run manually:

bash
Copy
Edit
cd infra
terraform init
terraform apply -auto-approve
Upload a .txt or .csv file to the created S3 bucket and check:

Lambda logs (CloudWatch)

Email notification (via SNS)

✅ Lambda Function Logic
Triggered by file upload to S3.

Extracts metadata (bucket name, file name, timestamp).

Publishes a notification to SNS with file details.

Logs all actions for auditing and debugging.

📬 Notifications
Email notifications are sent via SNS and include:

File name

Upload time

Bucket location

Ensure your email subscription to the SNS topic is confirmed.

🧪 Testing
Upload a test file:

bash
Copy
Edit
aws s3 cp test.txt s3://<your-bucket-name>/
Check:

CloudWatch logs

Email inbox

Terraform output for API URL (if using API Gateway)

🛡️ Security
IAM roles ensure least privilege.

Environment variables control sensitive config like SNS topic.

CORS headers set for API Gateway access (if applicable).

👩🏾‍💻 Author
Nothando Ndlovu
Cloud | DevOps | AI Enthusiast
GitHub | LinkedIn

🏫 Future Improvements
Add UI for teachers to upload and view marks.

Store parsed data in DynamoDB or RDS for analysis.

Include authentication for secure API access.
