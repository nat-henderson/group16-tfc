terraform {
  required_version = ">= 0.12.0"
  backend "remote" {
    organization = "group16"

    workspaces {
      name = "group16-team1"
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

data "aws_eks_cluster" "cluster_prod" {
  name = var.prod_cluster_name
}

data "aws_eks_cluster_auth" "cluster_prod" {
  name = var.prod_cluster_name
}
data "aws_eks_cluster" "cluster_test" {
  name = var.test_cluster_name
}

data "aws_eks_cluster_auth" "cluster_test" {
  name = var.test_cluster_name
}

data "aws_eks_cluster" "cluster_dev" {
  name = var.dev_cluster_name
}

data "aws_eks_cluster_auth" "cluster_dev" {
  name = var.dev_cluster_name
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

resource "kubernetes_namespace" "prod" {
  metadata {
    annotations = {
      team_name = var.team_name
    }

    name = "namespace-${var.team_id}"
  }
  provider = kubernetes.prod
}
resource "kubernetes_namespace" "dev" {
  metadata {
    annotations = {
      team_name = var.team_name
    }

    name = "namespace-${var.team_id}"
  }
  provider = kubernetes.dev
}
resource "kubernetes_namespace" "test" {
  metadata {
    annotations = {
      team_name = var.team_name
    }

    name = "namespace-${var.team_id}"
  }
  provider = kubernetes.test
}
