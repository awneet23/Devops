#!/bin/bash
set -e

APP_PRIVATE_IP=$1

sudo apt-get update -y
sudo apt-get install -y nginx

sudo cp /tmp/index.html /var/www/html/index.html

sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /api/ {
        proxy_pass http://${APP_PRIVATE_IP}:8080/;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "NimbusCart Web tier configured successfully."
