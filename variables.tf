variable "region" {
  type = string
}
variable "name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}