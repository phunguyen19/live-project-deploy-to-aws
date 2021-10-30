variable "aws_access_key" {
  description = "AWS Credentials Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Credentials Secret Key"
  type        = string
  sensitive   = true
}


variable "prefix" {
  description = "Prefix for all names"
  default     = "lpdtaws"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones for VPC"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "vpc_public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "tags" {
  description = "Tags to apply to resources created by VPC module"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
    Project     = "lpdtaws"
  }
}
