variable "project" {
  type = string
}

variable "environment" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = ""
}

variable "az" {
  type        = list(string)
  description = "Availability Zones"
  default     = []
}

variable "vpc_cidr" {
  type        = string
  description = "Suggest /16 as the primary solution to initiate a new VPC. Use lower CIDR if you wants more IP in individual subnets. (/16, Will give 256 address for every subnet.)"
}

variable "subnet_indexes" {
  type = object({
    ingress = list(number)
    egress  = list(number)
    private = list(number)
  })
  default = {
    ingress = [1, 2, 3]
    egress  = [4, 5, 6]
    private = [7, 8, 9]
  }

  validation {
    condition     = min(flatten(values(var.subnet_indexes))...) < 240 # 240~255 reserved for endpoint subnets
    error_message = "Reserve index 0~4 for the endpoint subnets."
  }
  validation {
    condition     = ceil(log(max(flatten(values(var.subnet_indexes))...), 2)) < 10
    error_message = "Too many subnet (max index value higher than 1023) will cause the available address in subnet less than 64. The maximum index should not more than 1023."
  }
}

variable "subnet_newbits" {
  type    = number
  default = 8
  validation {
    condition     = 4 <= var.subnet_newbits && var.subnet_newbits < 11
    error_message = "Subnet new bits must great or equal than 4 and less than 11."
  }
}

variable "enable_multiple_nat_gateways" {
  type        = bool
  default     = false
  description = "Enable multiple NAT gateways for HA. If disable, only one NAT gateway for subnets in multiple az."
}

variable "enable_endpoints" {
  type    = bool
  default = true
}

variable "gateway_endpoint_services" {
  type    = list(string)
  default = ["s3", "dynamodb"]
}

variable "interface_endpoint_services" {
  type    = list(string)
  default = ["logs", "ecr.dkr", "ecr.api", "secretsmanager", "sqs", "sns", "ssm"]
}

variable "gateway_endpoint_service_names" {
  type    = list(string)
  default = []
}

variable "interface_endpoint_service_names" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}