output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "security_group_vpc" {
  description = "Security group of vpc"
  value       = aws_security_group.SG.id
}

output "subnet1" {
  description = "Subnet1 ID"
  value       = aws_subnet.subnet1.id
}

output "subnet2" {
  description = "Subnet2 ID"
  value       = aws_subnet.subnet2.id
}