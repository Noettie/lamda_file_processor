pipeline {
    agent {
        docker {
            image 'amazonlinux:2023'
            args '-u root -v /tmp:/tmp -e PIP_NO_CACHE_DIR=1'
        }
    }
    tools {
        git 'Default'  // Configure Git in Jenkins settings
    }
    stages {
        stage('Install Dependencies') {
            steps {
                sh '''
                    yum update -y
                    yum install -y python3 python3-pip zip
                    pip3 install --upgrade pip
                '''
            }
        }
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }
        stage('Install Python Dependencies') {
            steps {
                sh 'cd lambda && pip3 install -r requirements.txt -t .'
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

