locals {
  max_amount_az_usage               = min(length(local.az), max(length(var.subnet_indexes.egress), length(var.subnet_indexes.ingress), length(var.subnet_indexes.private)))
  endpoints_subnet_reversed_indexes = var.enable_endpoints ? [for idx in range(local.max_amount_az_usage) : idx] : []
  gateway_endpoint_service_names    = length(var.gateway_endpoint_service_names) > 0 ? var.gateway_endpoint_services : data.aws_vpc_endpoint_service.gateway.*.service_name
  interface_endpoint_service_names  = length(var.interface_endpoint_service_names) > 0 ? var.interface_endpoint_services : data.aws_vpc_endpoint_service.interface.*.service_name
  gateway_endpoint_display_names    = [for name in local.gateway_endpoint_service_names : join("-", slice(split(".", name), 3, length(split(".", name))))]
  interface_endpoint_display_names  = [for name in local.interface_endpoint_service_names : join("-", slice(split(".", name), 3, length(split(".", name))))]
}


data "aws_vpc_endpoint_service" "gateway" {
  count        = length(var.gateway_endpoint_services)
  service      = element(var.gateway_endpoint_services, count.index)
  service_type = "Gateway"
}

data "aws_vpc_endpoint_service" "interface" {
  count        = length(var.interface_endpoint_services)
  service      = element(var.interface_endpoint_services, count.index)
  service_type = "Interface"
}


######
# SG #
######
resource "aws_security_group" "aws_endpoints" {
  name   = "${var.project}-${local.environment}-vpce"
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Environment = "${var.project}-${local.environment}"
    Name        = "${var.project}-${local.environment}-sg-vpce"
  }, var.tags)
}

resource "aws_security_group_rule" "aws_service_endpoint_https_ingress" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.aws_endpoints.id
}

resource "aws_security_group_rule" "aws_service_endpoint_https_ingress_v6" {
  type             = "ingress"
  from_port        = 443
  to_port          = 443
  protocol         = "tcp"
  ipv6_cidr_blocks = ["::/0"]

  security_group_id = aws_security_group.aws_endpoints.id
}


########
# VPCe #
########
resource "aws_vpc_endpoint" "gateway" {
  count             = length(local.gateway_endpoint_service_names)
  vpc_id            = aws_vpc.vpc.id
  service_name      = local.gateway_endpoint_service_names[count.index]
  vpc_endpoint_type = "Gateway"

  tags = merge({
    Environment = "${var.project}-${local.environment}"
    Name        = "${var.project}-${local.environment}-vpce-${local.gateway_endpoint_display_names[count.index]}"
  }, var.tags)
}

resource "aws_vpc_endpoint" "interface" {
  count               = length(local.interface_endpoint_service_names)
  vpc_id              = aws_vpc.vpc.id
  service_name        = local.interface_endpoint_service_names[count.index]
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.interface_endpoint.*.id
  security_group_ids  = [aws_security_group.aws_endpoints.id]
  private_dns_enabled = true

  tags = merge({
    Environment = "${var.project}-${local.environment}"
    Name        = "${var.project}-${local.environment}-vpce-${local.interface_endpoint_display_names[count.index]}"
  }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}


##########
# Subnet #
##########
resource "aws_subnet" "interface_endpoint" {
  count                           = length(local.endpoints_subnet_reversed_indexes)
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet(var.vpc_cidr, 9, 511 - local.endpoints_subnet_reversed_indexes[count.index])
  availability_zone               = element(local.az, count.index)
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, 255 - local.endpoints_subnet_reversed_indexes[count.index])

  tags = merge({
    Name        = "${var.project}-${local.environment}-subnet-endpoint-${element(local.az_names, count.index)}"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)

  depends_on = [data.aws_availability_zones.this]
}


############
#    RT    #
############
resource "aws_route_table" "endpoint" {
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name        = "${var.project}-${local.environment}-rt-endpoint"
    Environment = "${var.project}-${local.environment}"
  }, var.tags)
}

resource "aws_vpc_endpoint_route_table_association" "endpoint_gateway" {
  count           = length(aws_vpc_endpoint.gateway)
  route_table_id  = aws_route_table.endpoint.id
  vpc_endpoint_id = aws_vpc_endpoint.gateway[count.index].id
}

resource "aws_route_table_association" "endpoint" {
  count          = length(local.endpoints_subnet_reversed_indexes)
  route_table_id = aws_route_table.endpoint.id
  subnet_id      = aws_subnet.interface_endpoint[count.index].id
}


