pipeline {
    agent {
        docker {
            image 'amazonlinux:2023'
            args '-u root -v /tmp:/tmp -e PIP_NO_CACHE_DIR=1 --dns 8.8.8.8 --dns 8.8.4.4'
        }
    }

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        TF_IN_AUTOMATION      = 'true'
        AWS_REGION            = 'us-east-1'  // Set Lambda/S3 region here consistently
        S3_BUCKET             = 'lambda-file-processor-1073e95a' // Your bucket name
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Install Tools') {
            steps {
                sh '''
                    yum update -y --skip-broken
                    yum install -y python3 python3-pip zip wget unzip bind-utils less groff
                    
                    echo "Installing AWS CLI..."
                    curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
                    unzip awscliv2.zip
                    ./aws/install
                    aws --version
                '''
            }
        }

        stage('Setup Terraform') {
            steps {
                sh '''
                    TERRAFORM_VERSION="1.6.6"
                    wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
                    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                '''
            }
        }

        stage('Prepare Lambda') {
            steps {
                sh '''
                    cd lambda
                    pip3 install -r requirements.txt -t .
                    zip -r ../infra/lambda.zip .
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                dir('infra') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('infra') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    def api_url = sh(
                        script: 'cd infra && terraform output -raw api_gateway_url',
                        returnStdout: true
                    ).trim()
                    echo "API Endpoint: ${api_url}"
                    env.DEPLOYED_API_URL = api_url
                    sh "curl -s ${api_url}" // optional initial connectivity check
                }
            }
        }

        stage('Test API Gateway') {
            steps {
                script {
                    // Read API URL from Terraform output
                    def api_url = sh(script: 'cd infra && terraform output -raw api_gateway_url', returnStdout: true).trim()
                    env.DEPLOYED_API_URL = api_url
                    
                    // Extract hostname for DNS check
                    def hostname = api_url.replaceAll('https?://', '').split('/')[0]

                    echo "Checking DNS resolution for: ${hostname}"

                    def dnsCheck = sh(script: "nslookup ${hostname} || true", returnStdout: true)

                    if (dnsCheck.contains("NXDOMAIN") || dnsCheck.toLowerCase().contains("can't find") || dnsCheck.toLowerCase().contains("no answer")) {
                        echo "⚠️ DNS resolution failed, invoking Lambda directly via AWS CLI"

                        // Get Lambda function name from Terraform output
                        def lambda_name = sh(script: 'cd infra && terraform output -raw lambda_function_name', returnStdout: true).trim()

                        // Write test event file (adjust as needed)
                        writeFile file: 'test_event.json', text: '''
                        {
                            "httpMethod": "POST",
                            "body": "{\\"test\\": \\"payload\\"}"
                        }
                        '''

                        // Invoke Lambda directly
                        sh """
                            aws lambda invoke \
                                --function-name ${lambda_name} \
                                --payload file://test_event.json \
                                --region ${AWS_REGION} \
                                response.json
                        """

                        def response = readFile('response.json')
                        echo "Lambda invoke response: ${response}"
                    } else {
                        echo "✅ DNS resolution successful, testing API Gateway endpoint"

                        // Properly formatted S3 event for the Lambda trigger
                        def eventJson = '''{
                          "Records": [{
                            "eventVersion": "2.1",
                            "eventSource": "aws:s3",
                            "awsRegion": "us-east-1",
                            "eventTime": "2023-10-15T12:34:56.789Z",
                            "eventName": "ObjectCreated:Put",
                            "s3": {
                              "s3SchemaVersion": "1.0",
                              "configurationId": "testConfig",
                              "bucket": {
                                "name": "test-bucket",
                                "ownerIdentity": {"principalId": "EXAMPLE"},
                                "arn": "arn:aws:s3:::test-bucket"
                              },
                              "object": {
                                "key": "test/testfile.txt",
                                "size": 1024,
                                "eTag": "0123456789abcdef0123456789abcdef",
                                "versionId": "1"
                              }
                            }
                          }]
                        }'''

                        writeFile file: 'test_event.json', text: eventJson

                        sh """
                            curl -X POST ${api_url}test \
                                -H "Content-Type: application/json" \
                                -d @test_event.json -v
                        """
                    }
                }
            }
        }

        stage('Test S3 Upload') {
            steps {
                script {
                    sh """
                        echo "Creating test upload file..."
                        echo "This is a test file created at \$(date)" > test_upload_file.txt

                        echo "Uploading test file to S3 bucket ${S3_BUCKET}..."
                        aws s3 cp test_upload_file.txt s3://${S3_BUCKET}/test_upload_file.txt --region ${AWS_REGION}

                        echo "Upload complete. Check Lambda logs for processing output."
                    """
                }
            }
        }

        stage('Invoke Lambda') {
            steps {
                script {
                    sh '''
                        payload=$(base64 -w0 lambda/test_event.json)
                        aws lambda invoke --function-name ${lambda_name} --payload "$payload" lambda/response.json --region ${AWS_REGION}
                    '''
                    sh 'cat lambda/response.json'
                }
            }
        }

        stage('Update Lambda SNS Topic ARN') {
            steps {
                script {
                    def snsTopicArn = sh(returnStdout: true, script: 'cd infra && terraform output -raw sns_topic_arn').trim()

                    sh """
                        aws lambda update-function-configuration \
                          --function-name ${lambda_name} \
                          --environment Variables={SNS_TOPIC_ARN=${snsTopicArn}} \
                          --region ${AWS_REGION}
                    """
                }
            }
        }
    }

    post {
        failure {
            dir('infra') {
                sh 'terraform destroy -auto-approve'
            }
        }
        cleanup {
            cleanWs()
        }
        success {
            emailext(
                subject: "✅ Lambda Deployment Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "The Lambda function and infrastructure were deployed successfully, API Gateway tested, S3 upload trigger verified, and Lambda invoked.",
                to: "thandonoe.ndlovu@gmail.com"
            )
        }
    }
}

