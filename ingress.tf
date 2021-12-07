locals {
  has_ingress = length(var.subnet_indexes.ingress) > 0 || length(var.subnet_indexes.egress) > 0 ? true : false
}

#############
#  Gateway  #
#############
resource "aws_internet_gateway" "igw" {
  count  = local.has_ingress ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name        = "${var.project}-${local.environment}-igw"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)
}


############
#  Subnet  #
############
resource "aws_subnet" "ingress" {
  count                           = length(var.subnet_indexes.ingress)
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet(var.vpc_cidr, var.subnet_newbits, var.subnet_indexes.ingress[count.index])
  availability_zone               = element(local.az, count.index)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, var.subnet_indexes.ingress[count.index])
  assign_ipv6_address_on_creation = true

  tags = merge({
    Environment = "${var.project}-${local.environment}"
    Name        = "${var.project}-${local.environment}-subnet-ingress-${element(local.az_names, count.index)}"
  }, var.tags)

  depends_on = [data.aws_availability_zones.this]
}


############
#    RT    #
############
resource "aws_route_table" "ingress" {
  count  = local.has_ingress ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name        = "${var.project}-${local.environment}-rt-ingress"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)
}

resource "aws_route" "igw" {
  count                  = local.has_ingress ? 1 : 0
  route_table_id         = aws_route_table.ingress[0].id
  gateway_id             = aws_internet_gateway.igw[0].id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "igw_ipv6" {
  count                       = local.has_ingress ? 1 : 0
  route_table_id              = aws_route_table.ingress[0].id
  gateway_id                  = aws_internet_gateway.igw[0].id
  destination_ipv6_cidr_block = "::/0"
}

resource "aws_vpc_endpoint_route_table_association" "ingress_gateway" {
  count           = local.has_ingress ? length(aws_vpc_endpoint.gateway) : 0
  route_table_id  = aws_route_table.ingress[0].id
  vpc_endpoint_id = aws_vpc_endpoint.gateway[count.index].id
}

resource "aws_route_table_association" "ingress" {
  count          = local.has_ingress ? length(var.subnet_indexes.ingress) : 0
  subnet_id      = aws_subnet.ingress[count.index].id
  route_table_id = aws_route_table.ingress[0].id
}

