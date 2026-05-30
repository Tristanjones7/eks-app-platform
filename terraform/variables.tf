variable "region" {
  type    = string
  default = "us-east-1"
}
variable "project_name" {
  type    = string
  default = "eks-app-platform"
}
variable "cluster_version" {
  type    = string
  default = "1.30"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "node_min_size" {
  type    = number
  default = 1
}
variable "node_max_size" {
  type    = number
  default = 3
}
