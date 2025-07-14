## Capstone Project 3: Complete CI/CD with Terraform

### What did I build?
In this project, I built a **fully automated CI/CD pipeline** using **Jenkins**, **Terraform**, and **Helm**.

### What have I learned?
I created a `Jenkinsfile` and Jenkins pipelines that used **Terraform** to provision a complete **EKS (Elastic Kubernetes Service) cluster** on **AWS**. For managing the Terraform state, I configured an **S3 bucket** as the remote backend. As part of the deployment process, I also deployed a **MySQL database** onto the EKS cluster using **Helm charts**.
This project helped me understand and apply:
- Infrastructure provisioning with **Terraform**
- Using **S3** as a backend for Terraform state files
- Deploying and managing applications on **EKS** using **Helm**
- Creating and managing **Jenkins pipelines** for end-to-end CI/CD automation

### My project description. 
The pipeline starts from code changes, triggers the Terraform process via Jenkins to provision the EKS infrastructure, sets up MySQL using Helm, and completes with the automated deployment of applications.  
This exercise gave me hands-on experience with modern DevOps tools and practices such as **Infrastructure as Code**, **GitOps workflows**, and **Kubernetes-based deployments**.



# CAPSTONE PROJECT-3 project execution


# 12 - Infrastructure as Code with Terraform
#### This project is for the Devops Bootcamp module "Infrastructure as Code with Terraform" 


## 📄 Included PDF Resources

CAPSTONE PROJECT-3

## Evidence / Proof

Here are my notes, work, solutions, and test results for the module **"Infrastructure as Code with Terraform"**:  
👉 [PDF Link to Module Notes & Work](./12-Infrastructure_as_Code_with_Terraform.pdf)


All of my notes, work, solutions, and test results can be found in the PDF 11-Kubernetes_on_AWS-EKS.pdf. 
My complete documentation, including all notes and tests from the bootcamp, is available in this repository: https://github.com/Saban39/my_devops-bootcamp-pdf-notes-and-solutions.git



## My notes, work, solutions, and test results for Module "Kubernetes on AWS"



<details>
<summary>Solution 1: Create Terraform project to spin up EKS cluster </summary>
 <br>

> EXERCISE 1: Create Terraform project to spin up EKS cluster

- Create a Terraform project that spins up an EKS cluster with the exact same setup that you created in the previous exercise, for the same Java Gradle application:

- Create EKS cluster with 3 Nodes and 1 Fargate profile only for your java application
Deploy Mysql with 3 replicas with volumes for data persistence using helm


- Create a separate git repository for your Terraform project, separate from the Java application, so that changes to the EKS cluster can be made by a separate team independent of the application changes themselves.

Step 1: In the first step, i created the following GitHub repository to provision a test EKS cluster using Terraform:
https://github.com/Saban39/terraform_eks_exercise.git


![Bildschirmfoto 2025-06-13 um 16 31 39](https://github.com/user-attachments/assets/4a905b94-efeb-4b24-9989-90156e3dc52f)


![Bildschirmfoto 2025-06-13 um 16 32 43](https://github.com/user-attachments/assets/78ba53a2-c2d0-415f-8154-feb91f2757c7)


eks-cluster.tf
```sh

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.20.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.k8s_version
  cluster_endpoint_public_access = true

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id
  tags = {
    environment = "bootcamp-sg"
  }
  # starting from EKS 1.23 CSI plugin is needed for volume provisioning.
  cluster_addons = {
    aws-ebs-csi-driver = {}
  } 

  # worker nodes
  eks_managed_node_groups = {
    nodegroup = {
      use_custom_templates = false
      instance_types       = ["t3.small"]
      node_group_name      = var.env_prefix

      min_size     = 1
      max_size     = 3
      desired_size = 3

      tags = {
        Name = "${var.env_prefix}"
      }   
      # EBS CSI Driver policy
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }  
    }
  }
  fargate_profiles = {
    profile = {
      name = "sg-fargate-profile"
      selectors = [
        {
          namespace = "app-sg"
        }
      ]
    }
  }
}

```
mysql.tf
```sh
# This gives back object with certificate-authority among other attributes: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster#attributes-reference
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}

# This gives us object with token: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth#attributes-reference  
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}

provider "kubernetes" {
# load_config_file       = "false"
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.cluster.endpoint
    token = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}

resource "helm_release" "mysql" {
  name       = "my-release"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mysql"
  version    = "9.14.0"
  timeout    = "1000" # seconds

  values = [
    "${file("values.yaml")}"
  ]

  # Set chart values individually
  set {
    name  = "volumePermissions.enabled" 
    value = true
  }
}
```
output.tf
```sh
output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "kubectl_config" {
  description = "kubectl config as generated by the module."
  value       = module.eks.aws_auth_configmap_yaml
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks.aws_auth_configmap_yaml
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = local.cluster_name
}

```
provider.tf
```sh
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


```
values.yaml
```sh
architecture: replication
auth:
  rootPassword: secret-root-pass
  database: my-app-db
  username: my-user
  password: my-pass

# enable init container that changes the owner and group of the persistent volume mountpoint to runAsUser:fsGroup
volumePermissions:
  enabled: true

secondary:
  # 1 primary and 2 secondary replicas
  replicaCount: 2
  persistence:
    accessModes: ["ReadWriteOnce"]
    # storage class for EKS volumes
    storageClass: gp2


```
variables.tf
```sh
variable env_prefix {
  default = "dev"
}

variable k8s_version {
  default = "1.28"
}

variable cluster_name {
  default = "cluster-sg"
}

variable region {
  default = "eu-central-1"
}
```
vpc.tf
```sh
terraform {
  backend "s3" {
    bucket = "sg-bucket-twn-exercise"
    key    = "sgapp/state.tfstate"
    region  = "eu-central-1"
  }
}

provider "aws" {
  region  = var.region
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = var.cluster_name 
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.2.0"

  name                 = "vpc-sg"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

```
Since the creation of the EKS cluster was taking too long, the terraform apply operation failed. Therefore, I split the apply commands using the -target option.

```sh
terraform apply -target=module.vpc -target=module.eks -auto-approve
aws eks wait cluster-active --name cluster-sg --region eu-central-1
terraform apply -auto-approve
```
<details>
<summary>My Terraform Destroy Output</summary>
<pre><code class="language-sh">
sgworker@MacBook-Pro-3.local /Users/sgworker/Desktop/terraform_eks_exercise [main]
% terraform  destroy 
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

helm_release.mysql: Destroying... [id=my-release]
random_string.suffix: Destroying... [id=wcdZdqlj]
random_string.suffix: Destruction complete after 0s
module.vpc.aws_route_table_association.private[2]: Destroying... [id=rtbassoc-0d01df538bbf7e0f7]
module.vpc.aws_route_table_association.private[1]: Destroying... [id=rtbassoc-00ead463eef21c563]
module.vpc.aws_route_table_association.private[0]: Destroying... [id=rtbassoc-0518714dbee89bbbb]
module.eks.aws_iam_role_policy_attachment.cluster_encryption[0]: Destroying... [id=cluster-sg-cluster-20250613120049299500000003-20250613120111770300000012]
module.vpc.aws_default_route_table.default[0]: Destroying... [id=rtb-09d21b8df50128d89]
module.vpc.aws_route.private_nat_gateway[0]: Destroying... [id=r-rtb-0c9859564cfc946bc1080289494]
module.vpc.aws_default_security_group.this[0]: Destroying... [id=sg-0af01004acdac2e83]
module.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Destroying... [id=cluster-sg:aws-ebs-csi-driver]
module.vpc.aws_default_route_table.default[0]: Destruction complete after 0s
module.vpc.aws_default_security_group.this[0]: Destruction complete after 0s
module.vpc.aws_default_network_acl.this[0]: Destroying... [id=acl-091fd52e7296af4d4]
module.vpc.aws_route_table_association.public[2]: Destroying... [id=rtbassoc-088b5463246b08dad]
module.eks.aws_iam_openid_connect_provider.oidc_provider[0]: Destroying... [id=arn:aws:iam::524196012679:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/5B42FDAF9695D7E2B9A0EA3128866AB9]
module.vpc.aws_default_network_acl.this[0]: Destruction complete after 0s
module.eks.module.kms.aws_kms_alias.this["cluster"]: Destroying... [id=alias/eks/cluster-sg]
module.eks.module.kms.aws_kms_alias.this["cluster"]: Destruction complete after 0s
module.vpc.aws_route_table_association.public[0]: Destroying... [id=rtbassoc-03dc1fb38c161d900]
helm_release.mysql: Destruction complete after 1s
module.vpc.aws_route_table_association.public[1]: Destroying... [id=rtbassoc-08ae82c6d44d4aaa0]
module.vpc.aws_route_table_association.private[1]: Destruction complete after 0s
module.vpc.aws_route_table_association.private[2]: Destruction complete after 0s
module.eks.aws_ec2_tag.cluster_primary_security_group["environment"]: Destroying... [id=sg-00eec42a6f54fe4fb,environment]
module.vpc.aws_route.public_internet_gateway[0]: Destroying... [id=r-rtb-0f62b0837282312101080289494]
module.vpc.aws_route_table_association.private[0]: Destruction complete after 0s
module.vpc.aws_route_table_association.public[2]: Destruction complete after 0s
module.vpc.aws_route.private_nat_gateway[0]: Destruction complete after 1s
module.vpc.aws_nat_gateway.this[0]: Destroying... [id=nat-04e5629f5b4e8c58c]
module.vpc.aws_route_table.private[0]: Destroying... [id=rtb-0c9859564cfc946bc]
module.vpc.aws_route_table_association.public[0]: Destruction complete after 1s
module.eks.aws_iam_role_policy_attachment.cluster_encryption[0]: Destruction complete after 1s
module.eks.aws_iam_policy.cluster_encryption[0]: Destroying... [id=arn:aws:iam::524196012679:policy/cluster-sg-cluster-ClusterEncryption20250613120111174000000011]
module.eks.aws_ec2_tag.cluster_primary_security_group["environment"]: Destruction complete after 1s
module.eks.aws_iam_openid_connect_provider.oidc_provider[0]: Destruction complete after 1s
module.vpc.aws_route_table_association.public[1]: Destruction complete after 1s
module.vpc.aws_route.public_internet_gateway[0]: Destruction complete after 1s
module.vpc.aws_route_table.public[0]: Destroying... [id=rtb-0f62b083728231210]
module.eks.aws_iam_policy.cluster_encryption[0]: Destruction complete after 0s
module.vpc.aws_route_table.private[0]: Destruction complete after 0s
module.vpc.aws_route_table.public[0]: Destruction complete after 0s
module.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Destruction complete after 7s
module.eks.module.fargate_profile["profile"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Destroying... [id=sg-fargate-profile-20250613120049297600000002-20250613120050466000000004]
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.additional["AmazonEBSCSIDriverPolicy"]: Destroying... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050787000000009]
module.eks.module.fargate_profile["profile"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]: Destroying... [id=sg-fargate-profile-20250613120049297600000002-20250613120050486600000005]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Destroying... [id=cluster-sg:sg-fargate-profile]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Destroying... [id=cluster-sg:nodegroup-20250613122535165000000004]
module.eks.module.fargate_profile["profile"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Destruction complete after 0s
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.additional["AmazonEBSCSIDriverPolicy"]: Destruction complete after 0s
module.eks.module.fargate_profile["profile"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]: Destruction complete after 1s
module.vpc.aws_nat_gateway.this[0]: Still destroying... [id=nat-04e5629f5b4e8c58c, 10s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 10s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 10s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still destroying... [id=nat-04e5629f5b4e8c58c, 20s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 20s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 20s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still destroying... [id=nat-04e5629f5b4e8c58c, 30s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 30s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 30s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still destroying... [id=nat-04e5629f5b4e8c58c, 40s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 40s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 40s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still destroying... [id=nat-04e5629f5b4e8c58c, 50s elapsed]
module.vpc.aws_nat_gateway.this[0]: Destruction complete after 50s
module.vpc.aws_subnet.public[1]: Destroying... [id=subnet-0ecd018b60e48e4c1]
module.vpc.aws_eip.nat[0]: Destroying... [id=eipalloc-01c6a47c03daf5c3d]
module.vpc.aws_subnet.public[0]: Destroying... [id=subnet-015807c8aef8b5450]
module.vpc.aws_subnet.public[2]: Destroying... [id=subnet-01eda53e42f63e5cd]
module.vpc.aws_subnet.public[0]: Destruction complete after 1s
module.vpc.aws_subnet.public[2]: Destruction complete after 1s
module.vpc.aws_subnet.public[1]: Destruction complete after 1s
module.vpc.aws_eip.nat[0]: Destruction complete after 1s
module.vpc.aws_internet_gateway.this[0]: Destroying... [id=igw-015d0172dfa75ac88]
module.vpc.aws_internet_gateway.this[0]: Destruction complete after 1s
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 50s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 50s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 1m0s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 1m0s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 1m10s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 1m10s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 1m20s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 1m20s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Still destroying... [id=cluster-sg:sg-fargate-profile, 1m30s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 1m30s elapsed]
module.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Destruction complete after 1m35s
module.eks.module.fargate_profile["profile"].aws_iam_role.this[0]: Destroying... [id=sg-fargate-profile-20250613120049297600000002]
module.eks.module.fargate_profile["profile"].aws_iam_role.this[0]: Destruction complete after 1s
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 1m40s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 1m50s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 2m0s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 2m10s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 2m20s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 2m30s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 2m40s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 2m50s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 3m0s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 3m10s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 3m20s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 3m30s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 3m40s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 3m50s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 4m0s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 4m10s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 4m20s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 4m30s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 4m40s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 4m50s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 5m0s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 5m10s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 5m20s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 5m30s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 5m40s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 5m50s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 6m0s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Still destroying... [id=cluster-sg:nodegroup-20250613122535165000000004, 6m10s elapsed]
module.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Destruction complete after 6m19s
module.eks.module.eks_managed_node_group["nodegroup"].aws_launch_template.this[0]: Destroying... [id=lt-04682095139f03b4e]
module.eks.module.eks_managed_node_group["nodegroup"].aws_launch_template.this[0]: Destruction complete after 0s
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]: Destroying... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050636900000006]
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Destroying... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050686900000008]
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]: Destroying... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050643400000007]
module.eks.time_sleep.this[0]: Destroying... [id=2025-06-13T12:25:29Z]
module.eks.time_sleep.this[0]: Destruction complete after 0s
module.eks.aws_eks_cluster.this[0]: Destroying... [id=cluster-sg]
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]: Destruction complete after 0s
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Destruction complete after 0s
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]: Destruction complete after 0s
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role.this[0]: Destroying... [id=nodegroup-eks-node-group-20250613120049297600000001]
module.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role.this[0]: Destruction complete after 1s
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 1m0s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 1m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 1m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 1m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 1m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 1m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 2m0s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 2m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 2m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 2m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 2m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 2m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 3m0s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 3m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still destroying... [id=cluster-sg, 3m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Destruction complete after 3m24s
module.eks.aws_security_group_rule.node["ingress_cluster_kubelet"]: Destroying... [id=sgrule-2172602283]
module.eks.aws_security_group_rule.node["ingress_cluster_443"]: Destroying... [id=sgrule-485000510]
module.eks.aws_security_group_rule.node["egress_all"]: Destroying... [id=sgrule-2331104781]
module.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"]: Destroying... [id=sgrule-3145822388]
module.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"]: Destroying... [id=sgrule-1637821187]
module.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"]: Destroying... [id=sgrule-3743433599]
module.vpc.aws_subnet.private[2]: Destroying... [id=subnet-04d78a276a5d1de20]
module.eks.module.kms.aws_kms_key.this[0]: Destroying... [id=41a588e5-1790-4192-8a01-201e2eb3608b]
module.vpc.aws_subnet.private[1]: Destroying... [id=subnet-0d032311ec0f425f3]
module.vpc.aws_subnet.private[0]: Destroying... [id=subnet-06341af8f80200ebb]
module.eks.module.kms.aws_kms_key.this[0]: Destruction complete after 0s
module.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"]: Destroying... [id=sgrule-1880332386]
module.vpc.aws_subnet.private[2]: Destruction complete after 0s
module.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"]: Destroying... [id=sgrule-3134631952]
module.eks.aws_security_group_rule.node["ingress_cluster_kubelet"]: Destruction complete after 0s
module.eks.aws_cloudwatch_log_group.this[0]: Destroying... [id=/aws/eks/cluster-sg/cluster]
module.vpc.aws_subnet.private[0]: Destruction complete after 0s
module.eks.aws_iam_role_policy_attachment.this["AmazonEKSVPCResourceController"]: Destroying... [id=cluster-sg-cluster-20250613120049299500000003-2025061312005095670000000b]
module.vpc.aws_subnet.private[1]: Destruction complete after 0s
module.eks.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"]: Destroying... [id=cluster-sg-cluster-20250613120049299500000003-2025061312005091350000000a]
module.eks.aws_cloudwatch_log_group.this[0]: Destruction complete after 1s
module.eks.aws_security_group_rule.cluster["ingress_nodes_443"]: Destroying... [id=sgrule-1191843991]
module.eks.aws_security_group_rule.node["ingress_cluster_443"]: Destruction complete after 1s
module.eks.aws_security_group_rule.node["ingress_self_coredns_udp"]: Destroying... [id=sgrule-3561765773]
module.eks.aws_iam_role_policy_attachment.this["AmazonEKSVPCResourceController"]: Destruction complete after 1s
module.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"]: Destroying... [id=sgrule-2833075349]
module.eks.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"]: Destruction complete after 1s
module.eks.aws_iam_role.this[0]: Destroying... [id=cluster-sg-cluster-20250613120049299500000003]
module.eks.aws_security_group_rule.cluster["ingress_nodes_443"]: Destruction complete after 0s
module.eks.aws_security_group_rule.node["egress_all"]: Destruction complete after 1s
module.eks.aws_iam_role.this[0]: Destruction complete after 1s
module.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"]: Destruction complete after 2s
module.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"]: Destruction complete after 3s
module.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"]: Destruction complete after 3s
module.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"]: Destruction complete after 4s
module.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"]: Destruction complete after 4s
module.eks.aws_security_group_rule.node["ingress_self_coredns_udp"]: Destruction complete after 4s
module.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"]: Destruction complete after 4s
module.eks.aws_security_group.cluster[0]: Destroying... [id=sg-061dfc8d603975811]
module.eks.aws_security_group.node[0]: Destroying... [id=sg-07b8e1d172bb165c2]
module.eks.aws_security_group.cluster[0]: Destruction complete after 1s
module.eks.aws_security_group.node[0]: Destruction complete after 1s
module.vpc.aws_vpc.this[0]: Destroying... [id=vpc-0990fd42b5c05b8d2]
module.vpc.aws_vpc.this[0]: Destruction complete after 0s

Destroy complete! Resources: 62 destroyed.
</code></pre>
</details>

</details>



<details>
<summary>Solution 2:  Configure remote state </summary>
 <br>

> EXERCISE 2: Configure remote state
By default, TF stores state locally. You know that this is not practical when working in a team, because each user must make sure they always have the latest state data before running Terraform. To fix that, you

- Configure remote state with a remote data store for your terraform project
You can use e.g. S3 bucket for storage.

- Now, the platform team that manages K8s clusters want to make changes to the cluster configurations based on the Infrastructure as Code best practices:

- They collaborate and commit changes to git repository and those changes get applied to the cluster through a CI/CD pipeline.

- So the AWS infrastructure and K8s cluster changes will be deployed the same way as the application changes, using a CI/CD pipeline.

- So the team asks you to help them create a separate Jenkins pipeline for the Terraform project, in addition to your java-app pipeline from the previous module.

I created the following S3 bucket and successfully configured the Terraform remote state.

![Bildschirmfoto 2025-06-12 um 16 07 46](https://github.com/user-attachments/assets/d8731340-18f0-488c-b2b6-d56dab828a05)

</details>
<details>
<summary>Solution 3: CI/CD pipeline for Terraform project </summary>
 <br>

> EXERCISE 3: CI/CD pipeline for Terraform project

- Create a separate Jenkins pipeline for Terraform provisioning the EKS cluster

I had to extend the Jenkinsfile with the following stage because the build failed:
```sh
stage('Wait for EKS Cluster') {
  steps {
    echo "⏳ Waiting for EKS Cluster status ACTIVE"
    sh """
      export PATH=\$PATH:/usr/local/bin
      aws eks wait cluster-active \\
        --name \${TF_VAR_cluster_name} \\
        --region \${TF_VAR_region}
    """
  }
}
```


I have created the following Jenkinsfile: 


```sh
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
    sh '''
      export PATH=$PATH:/usr/local/bin
      export KUBECONFIG=/var/root/.kube/config

      aws eks update-kubeconfig \
        --name ${TF_VAR_cluster_name} \
        --region ${TF_VAR_region} \
        --kubeconfig $KUBECONFIG

      ${KUBECTL_BIN} --kubeconfig=$KUBECONFIG get nodes
    '''
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



```
![Bildschirmfoto 2025-06-13 um 16 26 35](https://github.com/user-attachments/assets/da2cb854-2838-4b86-b929-a089f943aab8)

```sh 

Started by user SG
Obtained Jenkinsfile from git https://github.com/Saban39/terraform_eks_exercise.git
[Pipeline] Start of Pipeline
[Pipeline] node
Running on Jenkins in /var/root/.jenkins/workspace/my-terraform-eks-pipeline
[Pipeline] {
[Pipeline] stage
[Pipeline] { (Declarative: Checkout SCM)
[Pipeline] checkout
Selected Git installation does not exist. Using Default
The recommended git tool is: NONE
using credential jenkins-access
 > git rev-parse --resolve-git-dir /var/root/.jenkins/workspace/my-terraform-eks-pipeline/.git # timeout=10
Fetching changes from the remote Git repository
 > git config remote.origin.url https://github.com/Saban39/terraform_eks_exercise.git # timeout=10
Fetching upstream changes from https://github.com/Saban39/terraform_eks_exercise.git
 > git --version # timeout=10
 > git --version # 'git version 2.39.5 (Apple Git-154)'
using GIT_ASKPASS to set credentials 
 > git fetch --tags --force --progress -- https://github.com/Saban39/terraform_eks_exercise.git +refs/heads/*:refs/remotes/origin/* # timeout=10
 > git rev-parse refs/remotes/origin/main^{commit} # timeout=10
Checking out Revision 6b87fda8aded9a1a1008e12c8af4505d71c682b7 (refs/remotes/origin/main)
 > git config core.sparsecheckout # timeout=10
 > git checkout -f 6b87fda8aded9a1a1008e12c8af4505d71c682b7 # timeout=10
Commit message: "restructured Jenkinsfile"
 > git rev-list --no-walk b52760320c395256b63b22db7621099e26d262bb # timeout=10
[Pipeline] }
[Pipeline] // stage
[Pipeline] withEnv
[Pipeline] {
[Pipeline] withCredentials
Masking supported pattern matches of $AWS_ACCESS_KEY_ID or $AWS_SECRET_ACCESS_KEY
[Pipeline] {
[Pipeline] withEnv
[Pipeline] {
[Pipeline] stage
[Pipeline] { (Terraform Init)
[Pipeline] sh
+ /usr/local/bin/terraform init -input=false

[0m[1mInitializing the backend...[0m
[0m[1mInitializing modules...[0m

[0m[1mInitializing provider plugins...[0m
- Reusing previous version of hashicorp/tls from the dependency lock file
- Reusing previous version of hashicorp/time from the dependency lock file
- Reusing previous version of hashicorp/cloudinit from the dependency lock file
- Reusing previous version of hashicorp/aws from the dependency lock file
- Reusing previous version of hashicorp/helm from the dependency lock file
- Reusing previous version of hashicorp/random from the dependency lock file
- Reusing previous version of hashicorp/kubernetes from the dependency lock file
- Using previously-installed hashicorp/cloudinit v2.3.7
- Using previously-installed hashicorp/aws v5.99.1
- Using previously-installed hashicorp/helm v2.17.0
- Using previously-installed hashicorp/random v3.7.2
- Using previously-installed hashicorp/kubernetes v2.37.1
- Using previously-installed hashicorp/tls v4.1.0
- Using previously-installed hashicorp/time v0.13.1

[0m[1m[32mTerraform has been successfully initialized![0m[32m[0m
[0m[32m
You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.[0m
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Apply VPC and EKS)
[Pipeline] echo
🌐 Provisioniere VPC und EKS (ohne Helm)
[Pipeline] sh
+ /usr/local/bin/terraform apply -target=module.vpc -target=module.eks -auto-approve
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_caller_identity.current: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_partition.current: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_caller_identity.current: Reading...[0m[0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_partition.current: Reading...[0m[0m
[0m[1mmodule.eks.module.kms.data.aws_partition.current[0]: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_partition.current: Read complete after 0s [id=aws][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_partition.current: Read complete after 0s [id=aws][0m
[0m[1mmodule.eks.module.kms.data.aws_caller_identity.current[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_partition.current: Reading...[0m[0m
[0m[1mmodule.eks.module.kms.data.aws_partition.current[0]: Read complete after 0s [id=aws][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_caller_identity.current: Reading...[0m[0m
[0m[1mmodule.eks.aws_cloudwatch_log_group.this[0]: Refreshing state... [id=/aws/eks/cluster-sg/cluster][0m
[0m[1mmodule.vpc.aws_vpc.this[0]: Refreshing state... [id=vpc-0990fd42b5c05b8d2][0m
[0m[1mdata.aws_availability_zones.available: Reading...[0m[0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_iam_policy_document.assume_role_policy[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_partition.current: Read complete after 0s [id=aws][0m
[0m[1mmodule.eks.data.aws_iam_policy_document.assume_role_policy[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_iam_policy_document.assume_role_policy[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=3016102342][0m
[0m[1mmodule.eks.data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=2764486067][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=2560088296][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].aws_iam_role.this[0]: Refreshing state... [id=sg-fargate-profile-20250613120049297600000002][0m
[0m[1mmodule.eks.aws_iam_role.this[0]: Refreshing state... [id=cluster-sg-cluster-20250613120049299500000003][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role.this[0]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_caller_identity.current: Read complete after 0s [id=524196012679][0m
[0m[1mmodule.eks.data.aws_caller_identity.current: Read complete after 0s [id=524196012679][0m
[0m[1mmodule.eks.data.aws_iam_session_context.current: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_iam_session_context.current: Read complete after 0s [id=arn:aws:iam::524196012679:user/admin][0m
[0m[1mmodule.eks.module.kms.data.aws_caller_identity.current[0]: Read complete after 0s [id=524196012679][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_caller_identity.current: Read complete after 0s [id=524196012679][0m
[0m[1mdata.aws_availability_zones.available: Read complete after 0s [id=eu-central-1][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050686900000008][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050636900000006][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.additional["AmazonEBSCSIDriverPolicy"]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050787000000009][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050643400000007][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Refreshing state... [id=sg-fargate-profile-20250613120049297600000002-20250613120050466000000004][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]: Refreshing state... [id=sg-fargate-profile-20250613120049297600000002-20250613120050486600000005][0m
[0m[1mmodule.vpc.aws_default_security_group.this[0]: Refreshing state... [id=sg-0af01004acdac2e83][0m
[0m[1mmodule.vpc.aws_default_route_table.default[0]: Refreshing state... [id=rtb-09d21b8df50128d89][0m
[0m[1mmodule.vpc.aws_default_network_acl.this[0]: Refreshing state... [id=acl-091fd52e7296af4d4][0m
[0m[1mmodule.vpc.aws_subnet.private[2]: Refreshing state... [id=subnet-04d78a276a5d1de20][0m
[0m[1mmodule.vpc.aws_subnet.private[0]: Refreshing state... [id=subnet-06341af8f80200ebb][0m
[0m[1mmodule.vpc.aws_subnet.private[1]: Refreshing state... [id=subnet-0d032311ec0f425f3][0m
[0m[1mmodule.vpc.aws_route_table.private[0]: Refreshing state... [id=rtb-0c9859564cfc946bc][0m
[0m[1mmodule.vpc.aws_internet_gateway.this[0]: Refreshing state... [id=igw-015d0172dfa75ac88][0m
[0m[1mmodule.vpc.aws_subnet.public[1]: Refreshing state... [id=subnet-0ecd018b60e48e4c1][0m
[0m[1mmodule.vpc.aws_subnet.public[0]: Refreshing state... [id=subnet-015807c8aef8b5450][0m
[0m[1mmodule.vpc.aws_subnet.public[2]: Refreshing state... [id=subnet-01eda53e42f63e5cd][0m
[0m[1mmodule.vpc.aws_route_table.public[0]: Refreshing state... [id=rtb-0f62b083728231210][0m
[0m[1mmodule.eks.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"]: Refreshing state... [id=cluster-sg-cluster-20250613120049299500000003-2025061312005091350000000a][0m
[0m[1mmodule.eks.aws_security_group.cluster[0]: Refreshing state... [id=sg-061dfc8d603975811][0m
[0m[1mmodule.eks.aws_security_group.node[0]: Refreshing state... [id=sg-07b8e1d172bb165c2][0m
[0m[1mmodule.eks.aws_iam_role_policy_attachment.this["AmazonEKSVPCResourceController"]: Refreshing state... [id=cluster-sg-cluster-20250613120049299500000003-2025061312005095670000000b][0m
[0m[1mmodule.vpc.aws_eip.nat[0]: Refreshing state... [id=eipalloc-01c6a47c03daf5c3d][0m
[0m[1mmodule.vpc.aws_route_table_association.private[0]: Refreshing state... [id=rtbassoc-0518714dbee89bbbb][0m
[0m[1mmodule.vpc.aws_route_table_association.private[2]: Refreshing state... [id=rtbassoc-0d01df538bbf7e0f7][0m
[0m[1mmodule.vpc.aws_route_table_association.private[1]: Refreshing state... [id=rtbassoc-00ead463eef21c563][0m
[0m[1mmodule.eks.module.kms.data.aws_iam_policy_document.this[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.kms.data.aws_iam_policy_document.this[0]: Read complete after 0s [id=3254987187][0m
[0m[1mmodule.vpc.aws_route.public_internet_gateway[0]: Refreshing state... [id=r-rtb-0f62b0837282312101080289494][0m
[0m[1mmodule.vpc.aws_route_table_association.public[0]: Refreshing state... [id=rtbassoc-03dc1fb38c161d900][0m
[0m[1mmodule.eks.module.kms.aws_kms_key.this[0]: Refreshing state... [id=41a588e5-1790-4192-8a01-201e2eb3608b][0m
[0m[1mmodule.vpc.aws_route_table_association.public[2]: Refreshing state... [id=rtbassoc-088b5463246b08dad][0m
[0m[1mmodule.vpc.aws_route_table_association.public[1]: Refreshing state... [id=rtbassoc-08ae82c6d44d4aaa0][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"]: Refreshing state... [id=sgrule-2833075349][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_443"]: Refreshing state... [id=sgrule-485000510][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"]: Refreshing state... [id=sgrule-3134631952][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_self_coredns_udp"]: Refreshing state... [id=sgrule-3561765773][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"]: Refreshing state... [id=sgrule-1637821187][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"]: Refreshing state... [id=sgrule-1880332386][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"]: Refreshing state... [id=sgrule-3145822388][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_kubelet"]: Refreshing state... [id=sgrule-2172602283][0m
[0m[1mmodule.eks.aws_security_group_rule.node["egress_all"]: Refreshing state... [id=sgrule-2331104781][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"]: Refreshing state... [id=sgrule-3743433599][0m
[0m[1mmodule.eks.aws_security_group_rule.cluster["ingress_nodes_443"]: Refreshing state... [id=sgrule-1191843991][0m
[0m[1mmodule.vpc.aws_nat_gateway.this[0]: Refreshing state... [id=nat-04e5629f5b4e8c58c][0m
[0m[1mmodule.eks.module.kms.aws_kms_alias.this["cluster"]: Refreshing state... [id=alias/eks/cluster-sg][0m
[0m[1mmodule.eks.aws_iam_policy.cluster_encryption[0]: Refreshing state... [id=arn:aws:iam::524196012679:policy/cluster-sg-cluster-ClusterEncryption20250613120111174000000011][0m
[0m[1mmodule.vpc.aws_route.private_nat_gateway[0]: Refreshing state... [id=r-rtb-0c9859564cfc946bc1080289494][0m
[0m[1mmodule.eks.aws_eks_cluster.this[0]: Refreshing state... [id=cluster-sg][0m
[0m[1mmodule.eks.aws_iam_role_policy_attachment.cluster_encryption[0]: Refreshing state... [id=cluster-sg-cluster-20250613120049299500000003-20250613120111770300000012][0m
[0m[1mmodule.eks.aws_ec2_tag.cluster_primary_security_group["environment"]: Refreshing state... [id=sg-00eec42a6f54fe4fb,environment][0m
[0m[1mmodule.eks.data.tls_certificate.this[0]: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"]: Reading...[0m[0m
[0m[1mdata.aws_eks_cluster.cluster: Reading...[0m[0m
[0m[1mdata.aws_eks_cluster_auth.cluster: Reading...[0m[0m
[0m[1mmodule.eks.time_sleep.this[0]: Refreshing state... [id=2025-06-13T12:25:29Z][0m
[0m[1mdata.aws_eks_cluster_auth.cluster: Read complete after 0s [id=cluster-sg][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Refreshing state... [id=cluster-sg:sg-fargate-profile][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_launch_template.this[0]: Refreshing state... [id=lt-04682095139f03b4e][0m
[0m[1mdata.aws_eks_cluster.cluster: Read complete after 0s [id=cluster-sg][0m
[0m[1mmodule.eks.data.tls_certificate.this[0]: Read complete after 0s [id=efc5619605e4300447be4c860675ff76c35033c7][0m
[0m[1mmodule.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"]: Read complete after 0s [id=aws-ebs-csi-driver][0m
[0m[1mmodule.eks.aws_iam_openid_connect_provider.oidc_provider[0]: Refreshing state... [id=arn:aws:iam::524196012679:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/5B42FDAF9695D7E2B9A0EA3128866AB9][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Refreshing state... [id=cluster-sg:nodegroup-20250613122535165000000004][0m
[0m[1mmodule.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Refreshing state... [id=cluster-sg:aws-ebs-csi-driver][0m

[0m[1m[32mNo changes.[0m[1m Your infrastructure matches the configuration.[0m

[0mTerraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
[33m╷[0m[0m
[33m│[0m [0m[1m[33mWarning: [0m[0m[1mResource targeting is in effect[0m
[33m│[0m [0m
[33m│[0m [0m[0mYou are creating a plan with the -target option, which means that the
[33m│[0m [0mresult of this plan may not represent all of the changes requested by the
[33m│[0m [0mcurrent configuration.
[33m│[0m [0m
[33m│[0m [0mThe -target option is not for routine use, and is provided only for
[33m│[0m [0mexceptional situations such as recovering from errors or mistakes, or when
[33m│[0m [0mTerraform specifically suggests to use it as part of an error message.
[33m╵[0m[0m
[33m╷[0m[0m
[33m│[0m [0m[1m[33mWarning: [0m[0m[1mApplied changes may be incomplete[0m
[33m│[0m [0m
[33m│[0m [0m[0mThe plan was created with the -target option in effect, so some changes
[33m│[0m [0mrequested in the configuration may have been ignored and the output values
[33m│[0m [0mmay not be fully updated. Run the following command to verify that no other
[33m│[0m [0mchanges are pending:
[33m│[0m [0m    terraform plan
[33m│[0m [0m	
[33m│[0m [0mNote that the -target option is not suitable for routine use, and is
[33m│[0m [0mprovided only for exceptional situations such as recovering from errors or
[33m│[0m [0mmistakes, or when Terraform specifically suggests to use it as part of an
[33m│[0m [0merror message.
[33m╵[0m[0m
[33m╷[0m[0m
[33m│[0m [0m[1m[33mWarning: [0m[0m[1mArgument is deprecated[0m
[33m│[0m [0m
[33m│[0m [0m[0m  with module.eks.aws_iam_role.this[0],
[33m│[0m [0m  on .terraform/modules/eks/main.tf line 292, in resource "aws_iam_role" "this":
[33m│[0m [0m 292: resource "aws_iam_role" "this" [4m{[0m[0m
[33m│[0m [0m
[33m│[0m [0minline_policy is deprecated. Use the aws_iam_role_policy resource instead.
[33m│[0m [0mIf Terraform should exclusively manage all inline policy associations (the
[33m│[0m [0mcurrent behavior of this argument), use the aws_iam_role_policies_exclusive
[33m│[0m [0mresource as well.
[33m│[0m [0m
[33m│[0m [0m(and one more similar warning elsewhere)
[33m╵[0m[0m
[0m[1m[32m
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
[0m[0m[1m[32m
Outputs:

[0mcluster_endpoint = "https://5B42FDAF9695D7E2B9A0EA3128866AB9.sk1.eu-central-1.eks.amazonaws.com"
cluster_name = "cluster-sg"
cluster_security_group_id = "sg-061dfc8d603975811"
config_map_aws_auth = <<EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::524196012679:role/nodegroup-eks-node-group-20250613120049297600000001
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::524196012679:role/sg-fargate-profile-20250613120049297600000002
      username: system:node:{{SessionName}}
      groups:
        - system:bootstrappers
        - system:nodes
        - system:node-proxier

EOT
kubectl_config = <<EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::524196012679:role/nodegroup-eks-node-group-20250613120049297600000001
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::524196012679:role/sg-fargate-profile-20250613120049297600000002
      username: system:node:{{SessionName}}
      groups:
        - system:bootstrappers
        - system:nodes
        - system:node-proxier

EOT
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Wait for EKS Cluster)
[Pipeline] echo
⏳ Warte auf EKS Cluster Status ACTIVE
[Pipeline] sh
+ export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
+ PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
+ aws eks wait cluster-active --name cluster-sg --region eu-central-1
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Read Terraform Outputs)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
📦 Lese Terraform Outputs
[Pipeline] sh
+ /usr/local/bin/terraform output -raw cluster_endpoint
[Pipeline] echo
✅ Cluster Endpoint: https://5B42FDAF9695D7E2B9A0EA3128866AB9.sk1.eu-central-1.eks.amazonaws.com
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Configure kubectl)
[Pipeline] echo
🔧 Konfiguriere Kubeconfig
[Pipeline] sh
+ export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
+ PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
+ export KUBECONFIG=/var/root/.kube/config
+ KUBECONFIG=/var/root/.kube/config
+ aws eks update-kubeconfig --name cluster-sg --region eu-central-1 --kubeconfig /var/root/.kube/config
Updated context arn:aws:eks:eu-central-1:524196012679:cluster/cluster-sg in /var/root/.kube/config
+ /usr/local/bin/kubectl --kubeconfig=/var/root/.kube/config get nodes
NAME                                          STATUS   ROLES    AGE   VERSION
ip-10-0-1-98.eu-central-1.compute.internal    Ready    <none>   75m   v1.28.15-eks-473151a
ip-10-0-2-145.eu-central-1.compute.internal   Ready    <none>   75m   v1.28.15-eks-473151a
ip-10-0-3-110.eu-central-1.compute.internal   Ready    <none>   75m   v1.28.15-eks-473151a
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Apply Helm/MySQL)
[Pipeline] echo
🚀 Helm/MySQL installieren
[Pipeline] sh
+ /usr/local/bin/terraform apply -auto-approve
[0m[1mrandom_string.suffix: Refreshing state... [id=wcdZdqlj][0m
[0m[1mdata.aws_availability_zones.available: Reading...[0m[0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_partition.current: Reading...[0m[0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_partition.current: Reading...[0m[0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_partition.current: Read complete after 0s [id=aws][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_partition.current: Read complete after 0s [id=aws][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_caller_identity.current: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_partition.current: Reading...[0m[0m
[0m[1mmodule.eks.aws_cloudwatch_log_group.this[0]: Refreshing state... [id=/aws/eks/cluster-sg/cluster][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_caller_identity.current: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_caller_identity.current: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_partition.current: Read complete after 0s [id=aws][0m
[0m[1mmodule.vpc.aws_vpc.this[0]: Refreshing state... [id=vpc-0990fd42b5c05b8d2][0m
[0m[1mmodule.eks.module.kms.data.aws_partition.current[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.kms.data.aws_caller_identity.current[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_iam_policy_document.assume_role_policy[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.kms.data.aws_partition.current[0]: Read complete after 0s [id=aws][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_iam_policy_document.assume_role_policy[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=3016102342][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=2560088296][0m
[0m[1mmodule.eks.data.aws_iam_policy_document.assume_role_policy[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.fargate_profile["profile"].aws_iam_role.this[0]: Refreshing state... [id=sg-fargate-profile-20250613120049297600000002][0m
[0m[1mmodule.eks.data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=2764486067][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role.this[0]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001][0m
[0m[1mmodule.eks.aws_iam_role.this[0]: Refreshing state... [id=cluster-sg-cluster-20250613120049299500000003][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].data.aws_caller_identity.current: Read complete after 0s [id=524196012679][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].data.aws_caller_identity.current: Read complete after 0s [id=524196012679][0m
[0m[1mmodule.eks.data.aws_caller_identity.current: Read complete after 0s [id=524196012679][0m
[0m[1mmodule.eks.data.aws_iam_session_context.current: Reading...[0m[0m
[0m[1mmodule.eks.data.aws_iam_session_context.current: Read complete after 0s [id=arn:aws:iam::524196012679:user/admin][0m
[0m[1mmodule.eks.module.kms.data.aws_caller_identity.current[0]: Read complete after 0s [id=524196012679][0m
[0m[1mdata.aws_availability_zones.available: Read complete after 0s [id=eu-central-1][0m
[0m[1mmodule.vpc.aws_default_route_table.default[0]: Refreshing state... [id=rtb-09d21b8df50128d89][0m
[0m[1mmodule.vpc.aws_default_security_group.this[0]: Refreshing state... [id=sg-0af01004acdac2e83][0m
[0m[1mmodule.eks.aws_security_group.cluster[0]: Refreshing state... [id=sg-061dfc8d603975811][0m
[0m[1mmodule.vpc.aws_internet_gateway.this[0]: Refreshing state... [id=igw-015d0172dfa75ac88][0m
[0m[1mmodule.vpc.aws_default_network_acl.this[0]: Refreshing state... [id=acl-091fd52e7296af4d4][0m
[0m[1mmodule.vpc.aws_route_table.public[0]: Refreshing state... [id=rtb-0f62b083728231210][0m
[0m[1mmodule.eks.aws_security_group.node[0]: Refreshing state... [id=sg-07b8e1d172bb165c2][0m
[0m[1mmodule.vpc.aws_subnet.private[1]: Refreshing state... [id=subnet-0d032311ec0f425f3][0m
[0m[1mmodule.vpc.aws_subnet.private[0]: Refreshing state... [id=subnet-06341af8f80200ebb][0m
[0m[1mmodule.vpc.aws_route_table.private[0]: Refreshing state... [id=rtb-0c9859564cfc946bc][0m
[0m[1mmodule.vpc.aws_subnet.private[2]: Refreshing state... [id=subnet-04d78a276a5d1de20][0m
[0m[1mmodule.vpc.aws_subnet.public[2]: Refreshing state... [id=subnet-01eda53e42f63e5cd][0m
[0m[1mmodule.vpc.aws_subnet.public[0]: Refreshing state... [id=subnet-015807c8aef8b5450][0m
[0m[1mmodule.vpc.aws_subnet.public[1]: Refreshing state... [id=subnet-0ecd018b60e48e4c1][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.additional["AmazonEBSCSIDriverPolicy"]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050787000000009][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050686900000008][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050643400000007][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]: Refreshing state... [id=nodegroup-eks-node-group-20250613120049297600000001-20250613120050636900000006][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]: Refreshing state... [id=sg-fargate-profile-20250613120049297600000002-20250613120050486600000005][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Refreshing state... [id=sg-fargate-profile-20250613120049297600000002-20250613120050466000000004][0m
[0m[1mmodule.vpc.aws_eip.nat[0]: Refreshing state... [id=eipalloc-01c6a47c03daf5c3d][0m
[0m[1mmodule.vpc.aws_route.public_internet_gateway[0]: Refreshing state... [id=r-rtb-0f62b0837282312101080289494][0m
[0m[1mmodule.eks.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"]: Refreshing state... [id=cluster-sg-cluster-20250613120049299500000003-2025061312005091350000000a][0m
[0m[1mmodule.eks.aws_iam_role_policy_attachment.this["AmazonEKSVPCResourceController"]: Refreshing state... [id=cluster-sg-cluster-20250613120049299500000003-2025061312005095670000000b][0m
[0m[1mmodule.vpc.aws_route_table_association.private[0]: Refreshing state... [id=rtbassoc-0518714dbee89bbbb][0m
[0m[1mmodule.vpc.aws_route_table_association.private[1]: Refreshing state... [id=rtbassoc-00ead463eef21c563][0m
[0m[1mmodule.vpc.aws_route_table_association.private[2]: Refreshing state... [id=rtbassoc-0d01df538bbf7e0f7][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"]: Refreshing state... [id=sgrule-1637821187][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"]: Refreshing state... [id=sgrule-3743433599][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"]: Refreshing state... [id=sgrule-2833075349][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_443"]: Refreshing state... [id=sgrule-485000510][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"]: Refreshing state... [id=sgrule-3145822388][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"]: Refreshing state... [id=sgrule-1880332386][0m
[0m[1mmodule.eks.aws_security_group_rule.node["egress_all"]: Refreshing state... [id=sgrule-2331104781][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_self_coredns_udp"]: Refreshing state... [id=sgrule-3561765773][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"]: Refreshing state... [id=sgrule-3134631952][0m
[0m[1mmodule.eks.aws_security_group_rule.node["ingress_cluster_kubelet"]: Refreshing state... [id=sgrule-2172602283][0m
[0m[1mmodule.vpc.aws_route_table_association.public[0]: Refreshing state... [id=rtbassoc-03dc1fb38c161d900][0m
[0m[1mmodule.vpc.aws_route_table_association.public[1]: Refreshing state... [id=rtbassoc-08ae82c6d44d4aaa0][0m
[0m[1mmodule.vpc.aws_route_table_association.public[2]: Refreshing state... [id=rtbassoc-088b5463246b08dad][0m
[0m[1mmodule.eks.aws_security_group_rule.cluster["ingress_nodes_443"]: Refreshing state... [id=sgrule-1191843991][0m
[0m[1mmodule.vpc.aws_nat_gateway.this[0]: Refreshing state... [id=nat-04e5629f5b4e8c58c][0m
[0m[1mmodule.eks.module.kms.data.aws_iam_policy_document.this[0]: Reading...[0m[0m
[0m[1mmodule.eks.module.kms.data.aws_iam_policy_document.this[0]: Read complete after 0s [id=3254987187][0m
[0m[1mmodule.eks.module.kms.aws_kms_key.this[0]: Refreshing state... [id=41a588e5-1790-4192-8a01-201e2eb3608b][0m
[0m[1mmodule.vpc.aws_route.private_nat_gateway[0]: Refreshing state... [id=r-rtb-0c9859564cfc946bc1080289494][0m
[0m[1mmodule.eks.module.kms.aws_kms_alias.this["cluster"]: Refreshing state... [id=alias/eks/cluster-sg][0m
[0m[1mmodule.eks.aws_iam_policy.cluster_encryption[0]: Refreshing state... [id=arn:aws:iam::524196012679:policy/cluster-sg-cluster-ClusterEncryption20250613120111174000000011][0m
[0m[1mmodule.eks.aws_eks_cluster.this[0]: Refreshing state... [id=cluster-sg][0m
[0m[1mmodule.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"]: Reading...[0m[0m
[0m[1mmodule.eks.time_sleep.this[0]: Refreshing state... [id=2025-06-13T12:25:29Z][0m
[0m[1mmodule.eks.data.tls_certificate.this[0]: Reading...[0m[0m
[0m[1mmodule.eks.aws_ec2_tag.cluster_primary_security_group["environment"]: Refreshing state... [id=sg-00eec42a6f54fe4fb,environment][0m
[0m[1mdata.aws_eks_cluster_auth.cluster: Reading...[0m[0m
[0m[1mdata.aws_eks_cluster.cluster: Reading...[0m[0m
[0m[1mdata.aws_eks_cluster_auth.cluster: Read complete after 0s [id=cluster-sg][0m
[0m[1mmodule.eks.module.fargate_profile["profile"].aws_eks_fargate_profile.this[0]: Refreshing state... [id=cluster-sg:sg-fargate-profile][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_launch_template.this[0]: Refreshing state... [id=lt-04682095139f03b4e][0m
[0m[1mmodule.eks.aws_iam_role_policy_attachment.cluster_encryption[0]: Refreshing state... [id=cluster-sg-cluster-20250613120049299500000003-20250613120111770300000012][0m
[0m[1mmodule.eks.data.tls_certificate.this[0]: Read complete after 0s [id=efc5619605e4300447be4c860675ff76c35033c7][0m
[0m[1mmodule.eks.aws_iam_openid_connect_provider.oidc_provider[0]: Refreshing state... [id=arn:aws:iam::524196012679:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/5B42FDAF9695D7E2B9A0EA3128866AB9][0m
[0m[1mdata.aws_eks_cluster.cluster: Read complete after 0s [id=cluster-sg][0m
[0m[1mmodule.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"]: Read complete after 0s [id=aws-ebs-csi-driver][0m
[0m[1mmodule.eks.module.eks_managed_node_group["nodegroup"].aws_eks_node_group.this[0]: Refreshing state... [id=cluster-sg:nodegroup-20250613122535165000000004][0m
[0m[1mmodule.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Refreshing state... [id=cluster-sg:aws-ebs-csi-driver][0m

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  [32m+[0m create[0m

Terraform will perform the following actions:

[1m  # helm_release.mysql[0m will be created
[0m  [32m+[0m[0m resource "helm_release" "mysql" {
      [32m+[0m[0m atomic                     = false
      [32m+[0m[0m chart                      = "mysql"
      [32m+[0m[0m cleanup_on_fail            = false
      [32m+[0m[0m create_namespace           = false
      [32m+[0m[0m dependency_update          = false
      [32m+[0m[0m disable_crd_hooks          = false
      [32m+[0m[0m disable_openapi_validation = false
      [32m+[0m[0m disable_webhooks           = false
      [32m+[0m[0m force_update               = false
      [32m+[0m[0m id                         = (known after apply)
      [32m+[0m[0m lint                       = false
      [32m+[0m[0m manifest                   = (known after apply)
      [32m+[0m[0m max_history                = 0
      [32m+[0m[0m metadata                   = (known after apply)
      [32m+[0m[0m name                       = "my-release"
      [32m+[0m[0m namespace                  = "default"
      [32m+[0m[0m pass_credentials           = false
      [32m+[0m[0m recreate_pods              = false
      [32m+[0m[0m render_subchart_notes      = true
      [32m+[0m[0m replace                    = false
      [32m+[0m[0m repository                 = "https://charts.bitnami.com/bitnami"
      [32m+[0m[0m reset_values               = false
      [32m+[0m[0m reuse_values               = false
      [32m+[0m[0m skip_crds                  = false
      [32m+[0m[0m status                     = "deployed"
      [32m+[0m[0m timeout                    = 1000
      [32m+[0m[0m values                     = [
          [32m+[0m[0m <<-EOT
                architecture: replication
                auth:
                  rootPassword: secret-root-pass
                  database: my-app-db
                  username: my-user
                  password: my-pass
                
                # enable init container that changes the owner and group of the persistent volume mountpoint to runAsUser:fsGroup
                volumePermissions:
                  enabled: true
                
                secondary:
                  # 1 primary and 2 secondary replicas
                  replicaCount: 2
                  persistence:
                    accessModes: ["ReadWriteOnce"]
                    # storage class for EKS volumes
                    storageClass: gp2
            EOT,
        ]
      [32m+[0m[0m verify                     = false
      [32m+[0m[0m version                    = "9.14.0"
      [32m+[0m[0m wait                       = true
      [32m+[0m[0m wait_for_jobs              = false

      [32m+[0m[0m set {
          [32m+[0m[0m name  = "volumePermissions.enabled"
          [32m+[0m[0m value = "true"
        }
    }

[1mPlan:[0m 1 to add, 0 to change, 0 to destroy.
[0m[0m[1mhelm_release.mysql: Creating...[0m[0m
[0m[1mhelm_release.mysql: Still creating... [10s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [20s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [30s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [40s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [50s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [1m0s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [1m10s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [1m20s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [1m30s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [1m40s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [1m50s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [2m0s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [2m10s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [2m20s elapsed][0m[0m
[0m[1mhelm_release.mysql: Still creating... [2m30s elapsed][0m[0m
[0m[1mhelm_release.mysql: Creation complete after 2m34s [id=my-release][0m
[33m╷[0m[0m
[33m│[0m [0m[1m[33mWarning: [0m[0m[1mArgument is deprecated[0m
[33m│[0m [0m
[33m│[0m [0m[0m  with module.eks.aws_iam_role.this[0],
[33m│[0m [0m  on .terraform/modules/eks/main.tf line 292, in resource "aws_iam_role" "this":
[33m│[0m [0m 292: resource "aws_iam_role" "this" [4m{[0m[0m
[33m│[0m [0m
[33m│[0m [0minline_policy is deprecated. Use the aws_iam_role_policy resource instead.
[33m│[0m [0mIf Terraform should exclusively manage all inline policy associations (the
[33m│[0m [0mcurrent behavior of this argument), use the aws_iam_role_policies_exclusive
[33m│[0m [0mresource as well.
[33m│[0m [0m
[33m│[0m [0m(and one more similar warning elsewhere)
[33m╵[0m[0m
[0m[1m[32m
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
[0m[0m[1m[32m
Outputs:

[0mcluster_endpoint = "https://5B42FDAF9695D7E2B9A0EA3128866AB9.sk1.eu-central-1.eks.amazonaws.com"
cluster_name = "cluster-sg"
cluster_security_group_id = "sg-061dfc8d603975811"
config_map_aws_auth = <<EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::524196012679:role/nodegroup-eks-node-group-20250613120049297600000001
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::524196012679:role/sg-fargate-profile-20250613120049297600000002
      username: system:node:{{SessionName}}
      groups:
        - system:bootstrappers
        - system:nodes
        - system:node-proxier

EOT
kubectl_config = <<EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::524196012679:role/nodegroup-eks-node-group-20250613120049297600000001
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::524196012679:role/sg-fargate-profile-20250613120049297600000002
      username: system:node:{{SessionName}}
      groups:
        - system:bootstrappers
        - system:nodes
        - system:node-proxier

EOT
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Declarative: Post Actions)
[Pipeline] sh
+ /usr/local/bin/terraform state pull
[Pipeline] archiveArtifacts
Archiving artifacts
[Pipeline] }
[Pipeline] // stage
[Pipeline] }
[Pipeline] // withEnv
[Pipeline] }
[Pipeline] // withCredentials
[Pipeline] }
[Pipeline] // withEnv
[Pipeline] }
[Pipeline] // node
[Pipeline] End of Pipeline
Finished: SUCCESS
```

</details>



