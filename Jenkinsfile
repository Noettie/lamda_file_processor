pipeline {
    agent {
        docker {
            image 'python:3.8-slim'  // Use Docker for isolation
            args '-v /tmp:/tmp'
        }
    }
    tools {
        git 'Default'  // Ensure Git is configured
    }
    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }
        stage('Install Python Dependencies') {
            steps {
                sh 'cd lambda && pip install -r requirements.txt -t .'
            }
        }
        stage('Package Lambda') {
            steps {
                sh 'zip -r lambda_function.zip lambda/*'
            }
        }
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }
        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
    post {
        always {
            sh 'rm -f lambda_function.zip'
        }
    }
}
