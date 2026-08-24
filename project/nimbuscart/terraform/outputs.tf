output "web_public_ip" {
  description = "Public IPv4 address of the Web EC2 instance"
  value       = aws_instance.web.public_ip
}

output "app_private_ip" {
  description = "Private IPv4 address of the App EC2 instance"
  value       = aws_instance.app.private_ip
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.nimbuscart_db.address
}

output "peering_connection_id" {
  description = "VPC peering connection ID"
  value       = aws_vpc_peering_connection.app_data_peering.id
}

output "nat_gateway_public_ip" {
  description = "Elastic IP address associated with the NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}

output "frontend_url" {
  description = "Public URL for the NimbusCart frontend"
  value       = "http://${aws_instance.web.public_ip}"
}
