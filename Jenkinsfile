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
                    yum install -y python3 python3-pip zip wget unzip curl
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

        stage('Test S3 Upload') {
            steps {
                script {
                    def bucket = sh(
                        script: 'cd infra && terraform output -raw file_bucket',
                        returnStdout: true
                    ).trim()

                    echo "Uploading test file to S3 bucket: ${bucket}"
                    sh """
                        echo 'test file content' > /tmp/test-upload.txt
                        aws s3 cp /tmp/test-upload.txt s3://${bucket}/lambda/test-upload.txt
                    """
                }
            }
        }

        stage('Test API Gateway') {
            steps {
                script {
                    def api_url = sh(
                        script: 'cd infra && terraform output -raw api_url',
                        returnStdout: true
                    ).trim()

                    echo "API Endpoint: ${api_url}"

                    def testPayload = '''{
                      "Records": [
                        {
                          "s3": {
                            "bucket": { "name": "dummy-bucket" },
                            "object": { "key": "dummy-key" }
                          },
                          "eventTime": "2024-01-01T00:00:00.000Z"
                        }
                      ]
                    }'''

                    writeFile file: 'test_event.json', text: testPayload

                    sh """
                        echo "Sending test event to API Gateway..."
                        response=$(curl -s -o response.txt -w "%{http_code}" -X POST -H "Content-Type: application/json" -d @test_event.json ${api_url})
                        echo "Response Code: \$response"
                        cat response.txt
                        if [ "\$response" -ne 200 ]; then
                            echo "API Gateway test failed"
                            exit 1
                        fi
                    """
                }
            }
        }
    }

    post {
        success {
            emailext(
                subject: "✅ Lambda Deployment Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Lambda function deployed and tested successfully via both S3 and API Gateway.",
                to: "thandonoe.ndlovu@gmail.com"
            )
        }

        failure {
            dir('infra') {
                sh 'terraform destroy -auto-approve'
            }
        }

        cleanup {
            cleanWs()
        }
    }
}

