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
                    # Update system and install base packages
                    yum update -y
                    yum install -y python3 python3-pip zip wget unzip

                    # Install Terraform (avoid directory conflicts)
                    TERRAFORM_VERSION="1.6.6"
                    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    
                    # Clean any existing terraform files
                    rm -f terraform 2>/dev/null || true
                    
                    # Install directly to /usr/local/bin
                    unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
                    chmod +x /usr/local/bin/terraform
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
                sh '''
                    cd lambda
                    pip3 install -r requirements.txt -t .
                '''
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
