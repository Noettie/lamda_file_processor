pipeline {
    agent {
        docker {
            image 'amazonlinux:2023'
            args '''
                -u root 
                -v /tmp:/tmp 
                -v /mnt/external_storage:/workspace 
                -e PIP_NO_CACHE_DIR=1
                --storage-opt size=20GB
            '''
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
                    # Minimal package installation
                    yum update -y --skip-broken
                    yum install -y python3 zip unzip wget
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

        stage('Package Lambda') {
            steps {
                sh '''
                    # Build directly in /tmp to avoid filling Jenkins workspace
                    cd lambda && zip -r /tmp/lambda_function.zip .
                '''
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('infra') {
                    sh '''
                        # Store plugins externally
                        terraform init -plugin-dir=/mnt/external_storage/tf_plugins
                        terraform apply -auto-approve
                    '''
                }
            }
        }
    }
    post {
        always {
            sh '''
                # Aggressive cleanup
                rm -rf /tmp/lambda_function.zip
                rm -rf .terraform*
            '''
        }
    }
}
