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
            steps { checkout scm }
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

        stage('Verify Deployment') {
            steps {
                script {
                    env.API_URL = sh(
                        script: 'cd infra && terraform output -raw api_url',
                        returnStdout: true
                    ).trim()

                    echo "API Endpoint: ${env.API_URL}"

                    // Replace `/process` with your actual resource path
                    sh "curl -s ${env.API_URL}process"
                }
            }
        }
    }

    post {
        success {
            script {
                slackSend(
                    color: 'good',
                    message: "✅ Lambda Deployment *Success* in `${env.JOB_NAME} #${env.BUILD_NUMBER}`.\nAPI: ${env.API_URL}",
                    channel: '#your-slack-channel' // Update to your actual channel
                )

                emailext(
                    subject: "✅ Lambda Deployment Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: "The Lambda function and infrastructure were deployed successfully.\nAPI URL: ${env.API_URL}",
                    to: "thandonoe.ndlovu@gmail.com",
                    recipientProviders: [[$class: 'DevelopersRecipientProvider'], [$class: 'RequesterRecipientProvider']],
                    replyTo: 'no-reply@example.com'
                )
            }
        }

        failure {
            slackSend(
                color: 'danger',
                message: "❌ Lambda Deployment *Failed* in `${env.JOB_NAME} #${env.BUILD_NUMBER}`. Check logs for more info.",
                channel: '#your-slack-channel'
            )

            emailext(
                subject: "❌ Lambda Deployment Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Deployment failed. Please check the logs.",
                to: "thandonoe.ndlovu@gmail.com"
            )
        }

        cleanup {
            cleanWs()
        }
    }
}

