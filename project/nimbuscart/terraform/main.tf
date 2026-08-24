terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}


# ============================================================
# Ubuntu AMI
# ============================================================

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}


# ============================================================
# APPLICATION VPC
# ============================================================

resource "aws_vpc" "app_vpc" {
  cidr_block           = var.app_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "nimbuscart-app-vpc"
  }
}


# ============================================================
# PUBLIC SUBNET
# ============================================================

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = true

  tags = {
    Name = "nimbuscart-public-subnet"
  }
}


# ============================================================
# PRIVATE APP SUBNET
# ============================================================

resource "aws_subnet" "app_private_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.app_private_subnet_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false

  tags = {
    Name = "nimbuscart-app-private-subnet"
  }
}


# ============================================================
# DATA VPC
# ============================================================

resource "aws_vpc" "data_vpc" {
  cidr_block           = var.data_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "nimbuscart-data-vpc"
  }
}


# ============================================================
# DATABASE SUBNET A
# ============================================================

resource "aws_subnet" "db_subnet_a" {
  vpc_id                  = aws_vpc.data_vpc.id
  cidr_block              = var.db_subnet_a_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false

  tags = {
    Name = "nimbuscart-db-subnet-a"
  }
}


# ============================================================
# DATABASE SUBNET B
# ============================================================

resource "aws_subnet" "db_subnet_b" {
  vpc_id                  = aws_vpc.data_vpc.id
  cidr_block              = var.db_subnet_b_cidr
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = false

  tags = {
    Name = "nimbuscart-db-subnet-b"
  }
}


# ============================================================
# INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "nimbuscart-app-igw"
  }
}


# ============================================================
# PUBLIC ROUTE TABLE
# ============================================================

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }

  tags = {
    Name = "nimbuscart-public-rt"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# ============================================================
# NAT GATEWAY
# ============================================================

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nimbuscart-nat-eip"
  }

  depends_on = [
    aws_internet_gateway.app_igw
  ]
}

resource "aws_nat_gateway" "app_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nimbuscart-app-nat"
  }

  depends_on = [
    aws_internet_gateway.app_igw
  ]
}


# ============================================================
# PRIVATE APPLICATION ROUTE TABLE
# ============================================================

resource "aws_route_table" "app_private_rt" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "nimbuscart-app-private-rt"
  }
}

resource "aws_route" "app_private_nat_route" {
  route_table_id         = aws_route_table.app_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.app_nat.id
}

resource "aws_route_table_association" "app_private_subnet_association" {
  subnet_id      = aws_subnet.app_private_subnet.id
  route_table_id = aws_route_table.app_private_rt.id
}


# ============================================================
# VPC PEERING
# ============================================================

resource "aws_vpc_peering_connection" "app_data_peering" {
  vpc_id      = aws_vpc.app_vpc.id
  peer_vpc_id = aws_vpc.data_vpc.id
  auto_accept = true

  tags = {
    Name = "nimbuscart-app-data-peering"
  }
}


# ============================================================
# APP VPC ROUTE TO DATA VPC
# ============================================================

resource "aws_route" "app_to_data" {
  route_table_id            = aws_route_table.app_private_rt.id
  destination_cidr_block    = var.data_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_data_peering.id
}


# ============================================================
# DATA VPC ROUTE TABLE
# ============================================================

resource "aws_route_table" "data_rt" {
  vpc_id = aws_vpc.data_vpc.id

  route {
    cidr_block                = var.app_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.app_data_peering.id
  }

  tags = {
    Name = "nimbuscart-data-rt"
  }
}

resource "aws_route_table_association" "db_subnet_a_association" {
  subnet_id      = aws_subnet.db_subnet_a.id
  route_table_id = aws_route_table.data_rt.id
}

resource "aws_route_table_association" "db_subnet_b_association" {
  subnet_id      = aws_subnet.db_subnet_b.id
  route_table_id = aws_route_table.data_rt.id
}


# ============================================================
# WEB SECURITY GROUP
# ============================================================

resource "aws_security_group" "web_sg" {
  name        = "nimbuscart-web-sg"
  description = "Security group for NimbusCart Web tier"
  vpc_id      = aws_vpc.app_vpc.id

  tags = {
    Name = "nimbuscart-web-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh" {
  security_group_id = aws_security_group.web_sg.id

  cidr_ipv4   = var.ssh_cidr
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_egress_rule" "web_outbound" {
  security_group_id = aws_security_group.web_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}


# ============================================================
# APP SECURITY GROUP
# ============================================================

resource "aws_security_group" "app_sg" {
  name        = "nimbuscart-app-sg"
  description = "Security group for NimbusCart App tier"
  vpc_id      = aws_vpc.app_vpc.id

  tags = {
    Name = "nimbuscart-app-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_api" {
  security_group_id = aws_security_group.app_sg.id

  referenced_security_group_id = aws_security_group.web_sg.id

  from_port   = var.app_port
  ip_protocol = "tcp"
  to_port     = var.app_port
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  security_group_id = aws_security_group.app_sg.id

  referenced_security_group_id = aws_security_group.web_sg.id

  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_egress_rule" "app_outbound" {
  security_group_id = aws_security_group.app_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}


# ============================================================
# DATABASE SECURITY GROUP
# ============================================================

resource "aws_security_group" "db_sg" {
  name        = "nimbuscart-db-sg"
  description = "Security group for NimbusCart PostgreSQL database"
  vpc_id      = aws_vpc.data_vpc.id

  tags = {
    Name = "nimbuscart-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_postgres" {
  security_group_id = aws_security_group.db_sg.id

  referenced_security_group_id = aws_security_group.app_sg.id

  from_port   = 5432
  ip_protocol = "tcp"
  to_port     = 5432

  depends_on = [
    aws_vpc_peering_connection.app_data_peering
  ]
}

resource "aws_vpc_security_group_egress_rule" "db_outbound" {
  security_group_id = aws_security_group.db_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}


# ============================================================
# RDS DB SUBNET GROUP
# ============================================================

resource "aws_db_subnet_group" "nimbuscart_db_subnet_group" {
  name = "nimbuscart-db-subnet-group"

  subnet_ids = [
    aws_subnet.db_subnet_a.id,
    aws_subnet.db_subnet_b.id
  ]

  tags = {
    Name = "nimbuscart-db-subnet-group"
  }
}


# ============================================================
# RDS POSTGRESQL
# ============================================================

resource "aws_db_instance" "nimbuscart_db" {
  identifier = "nimbuscart-db"

  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  port = 5432

  db_subnet_group_name = aws_db_subnet_group.nimbuscart_db_subnet_group.name

  vpc_security_group_ids = [
    aws_security_group.db_sg.id
  ]

  publicly_accessible = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "nimbuscart-db"
  }
}


# ============================================================
# ECR REPOSITORY
# ============================================================

resource "aws_ecr_repository" "nimbuscart_api" {
  name                 = "nimbuscart-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "nimbuscart-api"
  }
}


# ============================================================
# IAM ROLE FOR APP EC2
# ============================================================

resource "aws_iam_role" "app_ec2_role" {
  name = "nimbuscart-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_ecr_readonly" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "nimbuscart-app-instance-profile"
  role = aws_iam_role.app_ec2_role.name
}


# ============================================================
# WEB EC2 INSTANCE
# ============================================================

resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  tags = {
    Name = "nimbuscart-web"
  }
}


# ============================================================
# APP EC2 INSTANCE
# ============================================================

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.app_private_subnet.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = false
  key_name                    = var.key_name

  iam_instance_profile = aws_iam_instance_profile.app_instance_profile.name

  tags = {
    Name = "nimbuscart-app"
  }
}


# ============================================================
# BUILD AND PUSH API IMAGE TO ECR
# ============================================================

resource "terraform_data" "build_and_push_api" {

  triggers_replace = [
    aws_ecr_repository.nimbuscart_api.repository_url,
    filesha256("../app/api/Dockerfile"),
    filesha256("../app/api/server.js"),
    filesha256("../app/api/package.json"),
    filesha256("../app/api/package-lock.json")
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      aws ecr get-login-password --region ${var.aws_region} \
        | sudo docker login \
          --username AWS \
          --password-stdin ${split("/", aws_ecr_repository.nimbuscart_api.repository_url)[0]}

      sudo docker build \
        -t nimbuscart-api:latest \
        ../app/api

      sudo docker tag \
        nimbuscart-api:latest \
        ${aws_ecr_repository.nimbuscart_api.repository_url}:latest

      sudo docker push \
        ${aws_ecr_repository.nimbuscart_api.repository_url}:latest
    EOT
  }

  depends_on = [
    aws_ecr_repository.nimbuscart_api
  ]
}


# ============================================================
# DEPLOY APP TIER
# ============================================================

resource "terraform_data" "provision_app" {

  triggers_replace = [
    aws_instance.app.id,
    aws_db_instance.nimbuscart_db.address,
    terraform_data.build_and_push_api.id,
    filesha256("${path.module}/app.sh")
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(pathexpand(var.private_key_path))

    host = aws_instance.app.private_ip

    bastion_host        = aws_instance.web.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file(pathexpand(var.private_key_path))
  }

  provisioner "file" {
    source      = "${path.module}/app.sh"
    destination = "/tmp/app.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/app.sh",
      "sudo /tmp/app.sh '${var.aws_region}' '${aws_ecr_repository.nimbuscart_api.repository_url}' '${aws_db_instance.nimbuscart_db.address}' '${var.db_name}' '${var.db_username}' '${var.db_password}' '${var.app_port}'"
    ]
  }

  depends_on = [
    terraform_data.build_and_push_api,

    aws_instance.web,
    aws_instance.app,
    aws_db_instance.nimbuscart_db,

    aws_route.app_private_nat_route,
    aws_route.app_to_data,

    aws_route_table_association.public_subnet_association,
    aws_route_table_association.app_private_subnet_association,
    aws_route_table_association.db_subnet_a_association,
    aws_route_table_association.db_subnet_b_association,

    aws_vpc_security_group_ingress_rule.web_ssh,
    aws_vpc_security_group_ingress_rule.app_ssh,
    aws_vpc_security_group_ingress_rule.db_postgres
  ]
}


# ============================================================
# DEPLOY WEB TIER
# ============================================================

resource "terraform_data" "provision_web" {

  triggers_replace = [
    aws_instance.web.id,
    aws_instance.app.private_ip,
    filesha256("../app/frontend/index.html"),
    filesha256("${path.module}/web.sh")
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(pathexpand(var.private_key_path))
    host        = aws_instance.web.public_ip
  }

  provisioner "file" {
    source      = "../app/frontend/index.html"
    destination = "/tmp/index.html"
  }

  provisioner "file" {
    source      = "${path.module}/web.sh"
    destination = "/tmp/web.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/web.sh",
      "sudo /tmp/web.sh '${aws_instance.app.private_ip}'"
    ]
  }

  depends_on = [
    terraform_data.provision_app,

    aws_route_table_association.public_subnet_association,

    aws_vpc_security_group_ingress_rule.web_ssh,
    aws_vpc_security_group_ingress_rule.web_http,
    aws_vpc_security_group_ingress_rule.app_api
  ]
}
