#!/bin/bash

# Update package lists
sudo apt-get update -y

# Install Docker
sudo apt-get install -y docker.io

# Start Docker service
sudo systemctl start docker

# Enable Docker to start automatically
sudo systemctl enable docker

# Pull Nginx Docker image
sudo docker pull nginx

# Run Nginx container
sudo docker run -d --name nginx-server -p 80:80 nginx
