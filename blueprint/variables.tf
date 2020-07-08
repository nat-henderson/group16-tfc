variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "team_name" {
  type    = string
  default = "some team"
}

variable "team_id" {
  type    = string
  default = "some-team"
}
variable "prod_cluster_name" {
  type    = string
  default = "nmckinley-prod"
}

variable "test_cluster_name" {
  type    = string
  default = "nmckinley-test"
}

variable "dev_cluster_name" {
  type    = string
  default = "nmckinley-dev"
}
