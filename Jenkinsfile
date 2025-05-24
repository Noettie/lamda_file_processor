pipeline {
    agent any
    tools {
        git 'Default'  // must match the name from "Global Tool Configuration"
    }
    environment {
        AWS_REGION = 'us-east-1'
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm 
            }
        }

        stage('Install Python Dependencies') {
            steps {
                sh '''
                cd lambda
                pip install -r requirements.txt -t .
                '''
            }
        }

        stage('Package Lambda') {
            steps {
                sh '''
                cd lambda
                zip -r ../lambda_function.zip .
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f lambda_function.zip'  // Clean up
        }
    }
}

