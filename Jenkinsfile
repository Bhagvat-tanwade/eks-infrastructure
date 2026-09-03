
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
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh 'aws sts get-caller-identity'
                }
            }
        }

        stage('TERRAFORM PLAN') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh 'terraform plan'
                }
            }
        }

        stage('TERRAFORM APPLY') {
            steps {

                input message: 'Do you want to create EKS infrastructure?'

                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}
