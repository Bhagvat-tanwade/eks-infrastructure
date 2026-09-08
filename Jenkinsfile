
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
                dir('aws-services') {
                    sh 'terraform init'
                }
            }
        }

        stage('TERRAFORM VALIDATE') {
            steps {
                dir('aws-services') {
                    sh 'terraform validate'
                }
            }
        }

        stage('AWS AUTH CHECK') {
            steps {
                sh 'aws sts get-caller-identity'
            }
        }

        stage('TERRAFORM PLAN') {
            steps {
                dir('aws-services') {
                    sh 'terraform plan'
                }
            }
        }

        stage('TERRAFORM APPLY') {
            steps {
                input message: 'Do you want to create AWS services?'

                dir('aws-services') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}

