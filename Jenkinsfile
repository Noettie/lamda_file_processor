pipeline {
    agent {
        docker {
            image 'python:3.11-slim'  // Official Python image
            args '-v /tmp:/tmp'  // Optional volume mounts
        }
    }
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'  // Change to your region
    }
    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main',  // Change to your branch
                url: 'https://github.com/your-org/your-repo.git'  // Your repo URL
            }
        }

        stage('Set Up Python') {
            steps {
                sh 'python --version'
                sh 'pip install --upgrade pip'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'pip install -r requirements.txt -t lambda_function/'
            }
        }

        stage('Create Lambda ZIP') {
            steps {
                sh '''
                    echo "Creating ZIP file..."
                    zip -r9 lambda_function.zip lambda_function/
                    ls -al  # Verify ZIP creation
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                dir('infra') {  // Enter infra directory
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('infra') {  // Run from infra directory
                    sh '''
                        echo "Current directory: $(pwd)"
                        ls -al ../  # Verify ZIP exists in parent directory
                        terraform apply -auto-approve
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f lambda_function.zip'  // Cleanup ZIP file
            cleanWs()  // Optional workspace cleanup
        }
    }
}
