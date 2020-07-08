terraform {
  required_version = ">= 0.12.0"
  backend "remote" {
    organization = "group16"

    workspaces {
      name = "group16-tfc"
    }
  }
}

provider "aws" {
  version = ">= 2.28.1"
  region  = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::503249568911:role/nmckinley-terraform"
  }
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}


data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "test-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = "nmckinley-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

resource "aws_iam_role" "nmckinley" {
  name = "eks-cluster-nmckinley"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "nmckinley-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.nmckinley.name
}

resource "aws_iam_role_policy_attachment" "nmckinley-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.nmckinley.name
}

resource "aws_eks_cluster" "nmckinley" {
  for_each = toset(["prod", "test", "dev"])
  name     = "nmckinley-${each.value}"
  role_arn = aws_iam_role.nmckinley.arn

  vpc_config {
    subnet_ids = module.vpc.private_subnets
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.nmckinley-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.nmckinley-AmazonEKSServicePolicy,
  ]
}
data "aws_eks_cluster" "cluster_prod" {
  name = aws_eks_cluster.nmckinley["prod"].id
}

data "aws_eks_cluster_auth" "cluster_prod" {
  name = aws_eks_cluster.nmckinley["prod"].id
}
data "aws_eks_cluster" "cluster_test" {
  name = aws_eks_cluster.nmckinley["test"].id
}

data "aws_eks_cluster_auth" "cluster_test" {
  name = aws_eks_cluster.nmckinley["test"].id
}

data "aws_eks_cluster" "cluster_dev" {
  name = aws_eks_cluster.nmckinley["dev"].id
}

data "aws_eks_cluster_auth" "cluster_dev" {
  name = aws_eks_cluster.nmckinley["dev"].id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster_prod.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_prod.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster_prod.token
  load_config_file       = false
  version                = "~> 1.11"
  alias                  = "prod"
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster_test.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_test.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster_test.token
  load_config_file       = false
  version                = "~> 1.11"
  alias                  = "test"
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster_dev.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_dev.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster_dev.token
  load_config_file       = false
  version                = "~> 1.11"
  alias                  = "dev"
}

resource "kubernetes_namespace" "example" {
  for_each = { "team-1" : "foo",
  "team-2" : "bar" }
  metadata {
    annotations = {
      team_name = each.value
    }

    name = "namespace-${each.key}"
  }
  provider = kubernetes.prod
}
