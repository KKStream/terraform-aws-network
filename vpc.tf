resource "aws_vpc" "vpc" {
  cidr_block                       = var.vpc_cidr
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = merge({
    Name        = "${var.project}-${local.environment}-vpc"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)
}
