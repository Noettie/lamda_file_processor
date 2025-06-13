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
                    set -e
                    yum update -y --skip-broken
                    yum install -y python3 python3-pip zip wget unzip
                    rm -rf /var/cache/yum
                '''
            }
        }

        stage('Setup Terraform') {
            steps {
                sh '''
                    set -e
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
                    set -e
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
                    env.API_URL = sh(
                        script: 'cd infra && terraform output -raw api_url',
                        returnStdout: true
                    ).trim()

                    echo "✅ API Endpoint: ${env.API_URL}"

                    // Use a test path to avoid "Missing Authentication Token"
                    sh "curl -s ${env.API_URL}test || true"
                }
            }
        }
    }

    post {
        success {
            script {
                slackSend(
                    color: 'good',
                    message: "✅ Lambda Deployment *Success* in `${env.JOB_NAME} #${env.BUILD_NUMBER}`.\nAPI: ${env.API_URL}test",
                    channel: '#your-slack-channel' // 🔁 Update this to your real channel
                )

                emailext(
                    subject: "✅ Lambda Deployment Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """The Lambda function and infrastructure were deployed successfully.

API URL: ${env.API_URL}test
Job: ${env.JOB_NAME}
Build: ${env.BUILD_NUMBER}
""",
                    to: "thandonoe.ndlovu@gmail.com",
                    recipientProviders: [[$class: 'DevelopersRecipientProvider'], [$class: 'RequesterRecipientProvider']],
                    replyTo: 'no-reply@example.com'
                )
            }
        }

        failure {
            script {
                slackSend(
                    color: 'danger',
                    message: "❌ Lambda Deployment *Failed* in `${env.JOB_NAME} #${env.BUILD_NUMBER}`. Check logs.",
                    channel: '#your-slack-channel'
                )

                emailext(
                    subject: "❌ Lambda Deployment Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """Deployment failed for Job: ${env.JOB_NAME}
Build: ${env.BUILD_NUMBER}
Check Jenkins for logs.""",
                    to: "thandonoe.ndlovu@gmail.com"
                )
            }
        }

        cleanup {
            cleanWs()
        }
    }
}

