pipeline {
    agent {
        docker {
            image 'amazonlinux:2023'
            args '-u root -v /tmp:/tmp -e PIP_NO_CACHE_DIR=1'
        }
    }
    stages {
        stage('Install Dependencies') {
            steps {
                sh '''
                    # Install system dependencies
                    yum update -y
                    yum install -y python3 python3-pip zip wget unzip

                    # Install Terraform
                    TERRAFORM_VERSION="1.6.6"
                    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip  # -o = overwrite without prompting
                    mv terraform /usr/local/bin/
                    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
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
