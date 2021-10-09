terraform {
  required_version = ">= 0.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.62.0"
          }
       }

}


provider "aws" {
  region  = var.region
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_availability_zones" "available" {
}

resource "aws_security_group" "worker_group_sg" {
  name_prefix = "worker_group_sg"
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


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name                 = "eks"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets
  cluster_create_timeout = "1h"
  cluster_endpoint_private_access = true 

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name                          = "worker-group"
      instance_type                 = "t2.small"
      asg_desired_capacity          = 3
      additional_security_group_ids = [aws_security_group.worker_group_sg.id]
    },
  ]

}


provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

resource "helm_release" "istio_base" {
  name  = "istio-base"
  chart = "charts/base"

  timeout = 600
  cleanup_on_fail = true
  force_update    = true
  namespace       = "istio-system"


  depends_on = [kubernetes_namespace.istio_system]
}

resource "helm_release" "istiod" {
  name  = "istiod"
  chart = "charts/istio-discovery"

  timeout = 600
  cleanup_on_fail = true
  force_update    = true
  namespace       = "istio-system"


  depends_on = [kubernetes_namespace.istio_system]
}

resource "helm_release" "istio_ingress" {
  name  = "istio-ingress"
  chart = "charts/istio-ingress"

  timeout = 600
  cleanup_on_fail = true
  force_update    = true
  namespace       = "istio-system"


  depends_on = [kubernetes_namespace.istio_system]
}



resource "kubernetes_deployment" "hello-world" {
  metadata {
    name = "hello-world"
    labels = {
      app = "hello-world"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "hello-world"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }

      spec {
        container {
          image = var.app_image
          name  = "hello-world"

          
        }
      }
    }
  }
}

resource "kubernetes_service" "hello-world" {
  metadata {
    name = "hello-world-svc"
  }
  spec {
    selector = {
      app = "hello-world"
    }
    port {
      port        = var.app_port
      target_port = 80
    }

    type = "ClusterIP"
  }
}



