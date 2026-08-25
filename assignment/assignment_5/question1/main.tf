terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# Get the latest Ubuntu 24.04 LTS AMD64 AMI
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Security Group for Nginx Web Server
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-webserver-sg"
  description = "Security group for Nginx web server"

  # Allow SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port     = 0
    to_port       = 0
    protocol      = "-1"
    cidr_blocks   = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "nginx_server" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = "t3.micro"

  # AWS EC2 key pair name
  key_name = "custom-key-pair"

  # Attach Security Group
  security_groups = [aws_security_group.nginx_sg.name]

  # Send script.sh to the EC2 instance
  provisioner "file" {
    source      = "script.sh"
    destination = "/home/ubuntu/script.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("custom-key-pair.pem")
      host        = self.public_ip
    }
  }

  # Execute script.sh on the EC2 instance
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/script.sh",
      "sudo /home/ubuntu/script.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("custom-key-pair.pem")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "Nginx-Web-Server"
  }
}

# Output EC2 public IP
output "public_ip" {
  value = aws_instance.nginx_server.public_ip
}

# Output Nginx website URL
output "website_url" {
  value = "http://${aws_instance.nginx_server.public_ip}"
}
