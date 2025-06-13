#!/usr/bin/env groovy

pipeline {
  agent any

  environment {
    AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
    AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
    TERRAFORM_BIN         = '/usr/local/bin/terraform'
    KUBECTL_BIN         = '/usr/local/bin/kubectl'
    TF_VAR_env_prefix     = "dev"
    TF_VAR_k8s_version    = "1.28"
    TF_VAR_cluster_name   = "cluster-sg"
    TF_VAR_region         = "eu-central-1"
  }

  stages {
    stage('Terraform Init') {
      steps {
        sh "${TERRAFORM_BIN} init -input=false"
      }
    }

    stage('Apply VPC and EKS') {
      steps {
        echo "🌐 Provisioniere VPC und EKS (ohne Helm)"
        sh "${TERRAFORM_BIN} apply -target=module.vpc -target=module.eks -auto-approve"
      }
    }

    stage('Wait for EKS Cluster') {
      steps {
        echo "⏳ Warte auf EKS Cluster Status ACTIVE"
        sh """
          export PATH=$PATH:/usr/local/bin
          aws eks wait cluster-active \
            --name ${TF_VAR_cluster_name} \
            --region ${TF_VAR_region}
        """
      }
    }
 
    stage('Read Terraform Outputs') {
    steps {
        script {
            echo "📦 Lese Terraform Outputs"
            env.K8S_CLUSTER_ENDPOINT = sh(
            script: "${TERRAFORM_BIN} output -raw cluster_endpoint",
            returnStdout: true
            ).trim()

        echo "✅ Cluster Endpoint: ${env.K8S_CLUSTER_ENDPOINT}"
        }
    }
    }


    stage('Configure kubectl') {
      steps {
        echo "🔧 Konfiguriere Kubeconfig"
        sh """
          export PATH=$PATH:/usr/local/bin
          export KUBECONFIG=/var/root/.kube/config
          
          aws eks update-kubeconfig \
          --name ${TF_VAR_cluster_name} \
          --region ${TF_VAR_region} \
          --kubeconfig $KUBECONFIG
          ${KUBECTL_BIN} --kubeconfig=$KUBECONFIG get nodes
        """
         }
    }

    stage('Apply Helm/MySQL') {
      steps {
        echo "🚀 Helm/MySQL installieren"
        sh "${TERRAFORM_BIN} apply -auto-approve"
      }
    }
  }

  post {
    always {
      sh "${TERRAFORM_BIN} state pull > state-${BUILD_NUMBER}.tfstate"
      archiveArtifacts artifacts: "state-*.tfstate", onlyIfSuccessful: true
    }
  }
}
