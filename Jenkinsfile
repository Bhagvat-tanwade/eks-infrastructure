
pipeline {

    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
    }

    stages {

        stage('PULL') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Bhagvat-tanwade/eks-infrastructure.git'
            }
        }

        stage('TERRAFORM INIT') {
            steps {
                sh 'terraform init'
            }
        }

        stage('TERRAFORM VALIDATE') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('AWS AUTH CHECK') {
            steps {
                sh 'aws sts get-caller-identity'
            }
        }

        stage('TERRAFORM PLAN') {
            steps {
                sh 'terraform plan'
            }
        }

        stage('TERRAFORM APPLY') {
            steps {
                input message: 'Do you want to create AWS services?'
                sh 'terraform apply -auto-approve'
            }
        }
    }
}

