pipeline {
    agent {
        docker {
            image 'amazonlinux:2'  // Use Amazon Linux 2 (supports yum)
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }
    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        TF_IN_AUTOMATION     = 'true'
    }
    stages {
        // Stage 1: Install OS and Terraform dependencies
        stage('Install Dependencies') {
            steps {
                sh '''
                    yum update -y
                    yum install -y python3 python3-pip zip wget unzip
                    TERRAFORM_VERSION="1.6.6"
                    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
                    chmod +x /usr/local/bin/terraform
                    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                '''
            }
        }

        // Stage 2: Package Lambda code
        stage('Package Lambda') {
            steps {
                dir('python_app_lambda') {
                    sh '''
                        # Install Python dependencies (use pip3 for Python 3)
                        pip3 install -r requirements.txt -t .

                        # Create ZIP file
                        zip -r lambda_function.zip lambda_function.py *.py
                    '''
                }
            }
        }

        // Stage 3: Prepare Terraform directory
        stage('Prepare Terraform') {
            steps {
                dir('infra') {
                    sh 'cp ../python_app_lambda/lambda_function.zip .'
                }
            }
        }

        // Stage 4: Terraform Init
        stage('Terraform Init') {
            steps {
                dir('infra') {
                    sh 'terraform init'
                }
            }
        }

        // Stage 5: Terraform Apply
        stage('Terraform Apply') {
            steps {
                dir('infra') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        // Stage 6: Cleanup
        stage('Cleanup') {
            steps {
                dir('infra') {
                    sh 'rm -f lambda_function.zip'
                }
                dir('python_app_lambda') {
                    sh 'rm -f lambda_function.zip'
                }
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }
}
