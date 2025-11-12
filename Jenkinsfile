pipeline {
  agent none
  environment {
    AWS_REGION = 'us-east-1'
    ECR_REPO   = 'jenkins-nodejs-example'
    TF_DIR     = '.'
    APP_DIR    = 'app'
  }
  stages {
    stage('Checkout infra and app') {
      parallel {
        stage('Checkout infra (your repo)') {
          agent { kubernetes { inheritFrom 'git' } }
          steps { checkout scm }
        }
        stage('Clone Node.js app') {
          agent { kubernetes { inheritFrom 'git' } }
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
      agent { kubernetes { inheritFrom 'terraform' } }
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
      agent { kubernetes { inheritFrom 'terraform' } } // reuse terraform pod (has aws)
      environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
      }
      steps {
        container('aws') {
          script {
            def acct = sh(returnStdout: true, script: "aws sts get-caller-identity --query Account --output text").trim()
            env.ACCOUNT_ID = acct
            env.ECR_URL = "${acct}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}"
            echo "Resolved ECR: ${env.ECR_URL}"
          }
        }
      }
    }

    stage('Build & push image with Kaniko') {
      agent { kubernetes { inheritFrom 'kaniko' } }
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

    stage('Deploy to EKS') {
      agent { kubernetes { inheritFrom 'kubectl' } }
      environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
      }
      steps {
        container('aws') {
          sh "aws eks --region $AWS_REGION update-kubeconfig --name aws-final-project-eks"
        }
        container('kubectl') {
          sh """
            sed -i "s|:latest|:${BUILD_NUMBER}|g" k8s/deployment.yaml
            kubectl apply -f k8s/deployment.yaml
            kubectl apply -f k8s/service.yaml
          """
        }
      }
    }
  }
  post {
    success { echo "✅ Pipeline completed. Image pushed and deployed: ${env.ECR_URL}:${BUILD_NUMBER}" }
    failure { echo "❌ Pipeline failed. Check Terraform, Kaniko, or Deploy stages." }
  }
}
