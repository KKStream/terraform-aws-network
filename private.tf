locals {
  has_private = length(var.subnet_indexes.private) > 0 ? true : false
}

############
#  Subnet  #
############
resource "aws_subnet" "private" {
  count                           = length(var.subnet_indexes.private)
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet(var.vpc_cidr, var.subnet_newbits, var.subnet_indexes.private[count.index])
  availability_zone               = element(local.az, count.index)
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, var.subnet_indexes.private[count.index])

  tags = merge({
    Name        = "${var.project}-${local.environment}-subnet-private-${element(local.az_names, count.index)}"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)

  depends_on = [data.aws_availability_zones.this]
}


############
#    RT    #
############
resource "aws_route_table" "private" {
  count  = local.has_private ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name        = "${var.project}-${local.environment}-rt-private"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)
}

resource "aws_vpc_endpoint_route_table_association" "private_gateway" {
  count           = local.has_private ? length(aws_vpc_endpoint.gateway) : 0
  vpc_endpoint_id = aws_vpc_endpoint.gateway[count.index].id
  route_table_id  = aws_route_table.private[0].id
}

resource "aws_route_table_association" "private" {
  count          = length(var.subnet_indexes.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

