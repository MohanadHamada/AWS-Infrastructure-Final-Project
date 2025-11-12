pipeline {
  agent none
  environment {
    AWS_REGION = 'us-east-1'
    ECR_REPO   = 'jenkins-nodejs-example'
    TF_DIR     = 'AWS-Final-Project'
    APP_DIR    = 'app'
  }
  stages {
    stage('Checkout infra and app') {
      parallel {
        stage('Checkout infra (your repo)') {
          agent {
            kubernetes {
              label 'checkout-infra'
              yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: git
    image: alpine/git:latest
    command: ['cat']
    tty: true
"""
            }
          }
          steps {
            checkout scm
          }
        }
        stage('Clone Node.js app') {
          agent {
            kubernetes {
              label 'checkout-app'
              yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: git
    image: alpine/git:latest
    command: ['cat']
    tty: true
"""
            }
          }
          steps {
            sh """
              rm -rf ${APP_DIR}
              git clone https://github.com/mahmoud254/jenkins_nodejs_example.git ${APP_DIR}
            """
          }
        }
      }
    }

    stage('Terraform plan & apply') {
      agent {
        kubernetes {
          label 'tf'
          yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: terraform
    image: public.ecr.aws/hashicorp/terraform:1.8
    command: ['cat']
    tty: true
  - name: aws
    image: amazon/aws-cli:2.17.7
    command: ['cat']
    tty: true
"""
        }
      }
      environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
      }
      steps {
        container('aws') {
          sh 'aws sts get-caller-identity'
        }
        container('terraform') {
          dir("${TF_DIR}") {
            sh """
              terraform init -backend-config="region=${AWS_REGION}"
              terraform plan -out tfplan
              terraform apply -auto-approve tfplan
            """
          }
        }
      }
    }

    stage('Resolve ECR URL') {
      agent {
        kubernetes {
          label 'aws-cli'
          yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: aws
    image: amazon/aws-cli:2.17.7
    command: ['cat']
    tty: true
"""
        }
      }
      environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
      }
      steps {
        script {
          def acct = sh(returnStdout: true, script: "aws sts get-caller-identity --query Account --output text").trim()
          env.ACCOUNT_ID = acct
          env.ECR_URL = "${acct}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}"
          echo "Resolved ECR: ${env.ECR_URL}"
        }
      }
    }

    stage('Build & push image with Kaniko') {
      agent {
        kubernetes {
          label 'kaniko'
          yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: default
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:latest
    args: ["--version"]
    tty: true
"""
        }
      }
      environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
      }
      steps {
        sh """
          /kaniko/executor \
            --context=${APP_DIR} \
            --dockerfile=${APP_DIR}/Dockerfile \
            --destination=${ECR_URL}:latest \
            --destination=${ECR_URL}:${BUILD_NUMBER} \
            --use-new-run
        """
      }
    }
  }
  post {
    success {
      echo "Image pushed to ${env.ECR_URL}:${BUILD_NUMBER}"
    }
    failure {
      echo "Pipeline failed. Check Terraform and Kaniko stages."
    }
  }
}
