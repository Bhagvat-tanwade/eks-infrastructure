pipeline {
    agent any

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

        stage('TERRAFORM PLAN') {
            steps {
                sh 'terraform plan'
            }
        }

        stage('TERRAFORM APPLY') {
            steps {
                input message: 'Do you want to create EKS infrastructure?'
                sh 'terraform apply -auto-approve'
            }
        }
    }
}
