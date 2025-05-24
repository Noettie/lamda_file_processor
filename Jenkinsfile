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
        TF_IN_AUTOMATION     = 'true'
    }
    stages {
        stage('Install Dependencies') {
            steps {
                sh '''
                    yum update -y --skip-broken
                    yum install -y python3 python3-pip zip wget unzip
                    rm -rf /var/cache/yum
                '''
            }
        }

        stage('Install Terraform') {
            steps {
                sh '''
                    TERRAFORM_VERSION="1.6.6"
                    wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
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
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('infra') {  
                    sh '''
                    terraform apply -auto-approve <<EOF
                    {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Principal": {
                            "Service": "lambda.amazonaws.com"
                          },
                          "Action": "sts:AssumeRole"
                        }
                      ]
                    }
                    EOF
                    '''
                }
            }
        }
    }
    post {
        always {
            sh 'rm -rf infra/lambda_function.zip'
        }
    }
}
