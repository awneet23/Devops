variable "aws_region" {
  description = "AWS region for NimbusCart"
  type        = string
  default     = "ap-south-1"
}

variable "app_vpc_cidr" {
  description = "CIDR block for the application VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public web/NAT subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_private_subnet_cidr" {
  description = "CIDR block for the private application subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "data_vpc_cidr" {
  description = "CIDR block for the isolated data VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "db_subnet_a_cidr" {
  description = "CIDR block for the first database subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "db_subnet_b_cidr" {
  description = "CIDR block for the second database subnet"
  type        = string
  default     = "10.1.2.0/24"
}

variable "availability_zone_a" {
  description = "First availability zone"
  type        = string
  default     = "ap-south-1a"
}

variable "availability_zone_b" {
  description = "Second availability zone"
  type        = string
  default     = "ap-south-1b"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name used for SSH"
  type        = string
  default     = "nimbuscart-key"
}

variable "private_key_path" {
  description = "Local path to the PEM file used by Terraform provisioners"
  type        = string
  default     = "~/Downloads/nimbuscart-key.pem"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "nimbuscart"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "nimbus"
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "app_port" {
  description = "Port used by the Express API"
  type        = number
  default     = 8080
}


variable "ssh_cidr" {
  description = "CIDR block allowed to SSH into the Web tier"
  type        = string
}
