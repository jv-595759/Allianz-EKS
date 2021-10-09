variable "region" {
  default     = "us-east-2"
  description = "AWS region"
}

variable "cluster_name" {
  default = "eks-sandbox"
}

variable "app_image" {
  default = "nginxdemos/hello:0.2"
}

variable "app_port" {
  default = 80
}


