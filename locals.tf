locals {
  environment = var.environment != "" ? var.environment : terraform.workspace
  region      = var.region != "" ? var.region : data.aws_region.this.name
  az          = length(var.az) > 0 ? var.az : data.aws_availability_zones.this.names
  az_names    = [for name in local.az : split("-", name)[2]]
}

data "aws_region" "this" {}

data "aws_availability_zones" "this" {
  all_availability_zones = false
  state                  = "available"
}