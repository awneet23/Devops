#!/bin/bash
set -e

AWS_REGION=$1
ECR_REPOSITORY=$2
DB_HOST=$3
DB_NAME=$4
DB_USER=$5
DB_PASSWORD=$6
APP_PORT=$7

sudo apt-get update -y
sudo apt-get install -y docker.io unzip curl

if ! command -v aws >/dev/null 2>&1; then
  rm -rf /tmp/aws /tmp/awscliv2.zip

  curl -fL \
    --retry 3 \
    --connect-timeout 20 \
    "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "/tmp/awscliv2.zip"

  cd /tmp
  unzip -q -o awscliv2.zip

  sudo ./aws/install
fi

sudo systemctl enable docker
sudo systemctl start docker

aws ecr get-login-password --region "${AWS_REGION}" \
  | sudo docker login \
      --username AWS \
      --password-stdin "$(echo "${ECR_REPOSITORY}" | cut -d/ -f1)"

sudo docker pull "${ECR_REPOSITORY}:latest"

sudo docker rm -f nimbuscart-api 2>/dev/null || true

sudo docker run -d \
  --name nimbuscart-api \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  -e PORT="${APP_PORT}" \
  -e DB_HOST="${DB_HOST}" \
  -e DB_PORT="5432" \
  -e DB_USER="${DB_USER}" \
  -e DB_PASSWORD="${DB_PASSWORD}" \
  -e DB_NAME="${DB_NAME}" \
  -e DB_SSL="true" \
  "${ECR_REPOSITORY}:latest"

echo "NimbusCart API container started successfully."
