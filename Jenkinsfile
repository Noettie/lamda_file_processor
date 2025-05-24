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
                sh '''
                    # Create ZIP in infra directory
                    cd lambda && zip -r ../infra/lambda_function.zip .
                '''
            }
        }

        stage('Clean Before Terraform') {
            steps {
                sh '''
                    # Clean Terraform cache and Python artifacts
                    rm -rf infra/.terraform* infra/terraform.tfstate*
                    rm -rf lambda/__pycache__ lambda/*.pyc
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                dir('infra') {  
                    sh '''
                        # Store plugins in /tmp to conserve container space
                        terraform init -plugin-dir=/tmp/tf_plugins
                    '''
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
                # Aggressive cleanup
                rm -f infra/lambda_function.zip
                docker system prune -af --volumes  # Clean Docker artifacts
                rm -rf infra/.terraform* /tmp/tf_plugins
            '''
            cleanWs()
        }
    }
}

