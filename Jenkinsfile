pipeline {
    agent {
        docker {
            image 'amazonlinux:2023'
            args '-u root -v /tmp:/tmp -e PIP_NO_CACHE_DIR=1 --storage-opt=size=20GB'
        }
    }
    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        TF_IN_AUTOMATION     = 'true'
    }
    stages {
        stage('Install Dependencies') {
            steps {
                sh '''
                    # Cleanup to maximize disk space
                    rm -rf /var/cache/yum
                    yum clean all

                    # Install critical packages with minimal docs
                    yum update -y --setopt=tsflags=nodocs
                    yum install -y \
                        python3 \
                        python3-pip \
                        zip \
                        wget \
                        unzip \
                        --setopt=tsflags=nodocs \
                        --skip-broken
                '''
            }
        }

        stage('Install Terraform') {
            steps {
                sh '''
                    TERRAFORM_VERSION="1.6.6"
                    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
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
                sh 'cd lambda && pip3 install --no-cache-dir -r requirements.txt -t .'
            }
        }

        stage('Package Lambda') {
            steps {
                sh 'cd lambda && zip -r ../infra/lambda_function.zip .'
            }
        }

        stage('Terraform Init') {
            steps {
                dir('infra') {  
                    sh 'terraform init -plugin-dir=/tmp/tf_plugins'
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
    }
    post {
        always {
            sh '''
                # Cleanup workspace
                rm -rf infra/lambda_function.zip
                rm -rf infra/.terraform* 
            '''
            cleanWs()
        }
    }
}

