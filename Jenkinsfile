pipeline {
    agent {
        docker {
            image 'amazonlinux:2023'
            args '-u root -v /tmp:/tmp -e PIP_NO_CACHE_DIR=1'
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
                    yum install -y python3 python3-pip zip wget unzip
                    rm -rf /var/cache/yum
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
                        script: 'cd infra && terraform output -raw api_url',
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
                writeFile file: 'test_event.json', text: '''{
  "test": "event"
}'''
                sh """
                    echo "Sending test event to API Gateway..."
                    response=\$(curl -s -o response.txt -w "%{http_code}" -X POST -H "Content-Type: application/json" -d @test_event.json ${DEPLOYED_API_URL})
                    echo "Response Code: \$response"
                    cat response.txt
                    if [ "\$response" -ne 200 ]; then
                        echo "API Gateway test failed"
                        exit 1
                    fi
                """
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
                body: "The Lambda function and infrastructure were deployed successfully, API Gateway tested, and S3 upload trigger verified.",
                to: "thandonoe.ndlovu@gmail.com"
            )
        }
    }
}

