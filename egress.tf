locals {
  has_egress  = length(var.subnet_indexes.egress) > 0 ? true : false
  nat_numbers = local.has_egress ? (var.enable_multiple_nat_gateways ? length(local.az) : 1) : 0
  rt_numbers  = local.nat_numbers
}

#############
#  Gateway  #
#############
resource "aws_eip" "nat" {
  count = local.nat_numbers
  vpc   = true
}

resource "aws_nat_gateway" "nat" {
  count         = local.nat_numbers
  subnet_id     = element(aws_subnet.ingress.*.id, count.index)
  allocation_id = element(aws_eip.nat.*.id, count.index)

  tags = merge({
    Name        = "${var.project}-${local.environment}-nat-${local.az_names[count.index]}"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)
}

resource "aws_egress_only_internet_gateway" "egress_igw" {
  count  = local.has_egress ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name        = "${var.project}-${local.environment}-eigw"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)
}


############
#  Subnet  #
############
resource "aws_subnet" "egress" {
  count                           = length(var.subnet_indexes.egress)
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet(var.vpc_cidr, var.subnet_newbits, var.subnet_indexes.egress[count.index])
  availability_zone               = element(local.az, count.index)
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, var.subnet_indexes.egress[count.index])

  tags = merge({
    Environment = "${var.project}-${local.environment}"
    Name        = "${var.project}-${local.environment}-subnet-egress-${element(local.az_names, count.index)}"
  }, var.tags)

  depends_on = [data.aws_availability_zones.this]
}


############
#    RT    #
############
resource "aws_route_table" "egress" {
  count  = local.rt_numbers
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name        = "${var.project}-${local.environment}-rt-egress-${element(local.az_names, count.index)}"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route" "egress_nat" {
  count                  = local.rt_numbers
  route_table_id         = aws_route_table.egress[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat.*.id, count.index)
}

resource "aws_route" "egress_igw" {
  count                       = local.rt_numbers
  route_table_id              = aws_route_table.egress[count.index].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.egress_igw[0].id
}

resource "aws_vpc_endpoint_route_table_association" "egress_gateway" {
  count           = local.has_egress ? length(aws_vpc_endpoint.gateway) * local.rt_numbers : 0
  route_table_id  = element(aws_route_table.egress.*.id, count.index)
  vpc_endpoint_id = aws_vpc_endpoint.gateway[floor(count.index / local.rt_numbers)].id

  depends_on = [aws_route_table.egress, aws_vpc_endpoint.gateway]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route_table_association" "egress" {
  count          = local.has_egress ? length(var.subnet_indexes.egress) : 0
  subnet_id      = element(aws_subnet.egress.*.id, count.index)
  route_table_id = element(aws_route_table.egress.*.id, count.index)

  depends_on = [aws_subnet.egress, aws_route_table.egress]

  lifecycle {
    create_before_destroy = true
  }
}

