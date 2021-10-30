
output "vpc_id" {
  description = "ID of VPC"
  value       = module.vpc.vpc_id
}

output "vpc_public_subnets" {
  description = "IDs of the VPC's public subnets"
  value       = module.vpc.public_subnets
}
