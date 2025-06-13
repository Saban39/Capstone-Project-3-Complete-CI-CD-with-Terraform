#!/bin/bash

set -e

echo "🔧 Init Terraform"
terraform init

echo "🌐 Apply VPC & EKS"
terraform apply -target=module.vpc -target=module.eks -auto-approve

echo "⏳ Wait for EKS to be active"
aws eks wait cluster-active --name my-test-cluster --region eu-central-1

echo "📡 Update kubeconfig"
aws eks update-kubeconfig --name my-test-cluster --region eu-central-1

echo "🚀 Apply Helm/MySQL"
terraform apply -auto-approve
