output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "region" {
  value = local.region
}

output "az" {
  value = local.az
}

############
#  Egress  #
############
output "egress_subnet_ids" {
  value = aws_subnet.egress.*.id
}

output "egress_rt_id" {
  value = try(aws_route_table.egress[0].id, "")
}

output "egress_rt_ids" {
  value = try(aws_route_table.egress.*.id, [])
}

#############
#  Ingress  #
#############
output "ingress_subnet_ids" {
  value = aws_subnet.ingress.*.id
}

output "ingress_rt_id" {
  value = try(aws_route_table.ingress[0].id, "")
}


#############
#  Private  #
#############
output "private_subnet_ids" {
  value = aws_subnet.private.*.id
}

output "private_rt_id" {
  value = try(aws_route_table.private[0].id, "")
}


##############
#  Endpoint  #
##############
output "endpoint_subnet_ids" {
  value = aws_subnet.interface_endpoint.*.id
}

