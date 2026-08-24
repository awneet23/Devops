# NimbusCart DevOps Project

## Project Overview

NimbusCart is a three-tier product catalog application deployed on AWS using Terraform and Docker.

The application consists of:

- A static frontend served by Nginx on a public EC2 instance.
- A Dockerized Express REST API running on a private EC2 instance.
- A PostgreSQL database hosted using Amazon RDS.
- Separate application and data VPCs connected using VPC peering.
- Terraform used to provision and automate the AWS infrastructure.
- Amazon ECR used to store the Docker image.
- Amazon S3 used for Terraform remote state.

---

# Task A - Manual Deployment

## Local Application Testing

The application was first tested locally before deployment to AWS.

A PostgreSQL container was created using Docker with a persistent named volume.

The Express API provides the following endpoints:

- `GET /health`
- `GET /items`
- `POST /items`

The API automatically creates the `products` table when it starts.

The frontend was created using HTML, CSS, and JavaScript. It retrieves products from the API and allows new products to be added.

The Express API was containerized using Docker and tested against PostgreSQL.

The local deployment verified:

- `GET /health` returns HTTP 200.
- `GET /items` retrieves products.
- `POST /items` inserts products.
- The frontend displays products.
- The frontend displays an error when the API is unavailable.

## Manual VPC Peering Experiment

Before automating the AWS infrastructure, two temporary VPCs were created manually.

Application VPC:

`10.0.0.0/16`

Data VPC:

`10.1.0.0/16`

A VPC peering connection was created between them.

Initially, only the application-side route to the data VPC was configured. Communication failed because the data VPC had no return route.

After adding the return route:

`10.0.0.0/16 -> VPC Peering Connection`

communication succeeded.

This demonstrated that VPC peering requires routes in both directions.

The database subnet does not require a NAT Gateway because it does not need to initiate connections to the public Internet. It only needs private communication with the application tier.

The temporary manual resources were removed after testing.

---

# Task B - Scripting and Automation

Terraform and Bash were used to automate the AWS deployment.

The infrastructure includes:

- Application VPC
- Data VPC
- Public web subnet
- Private application subnet
- Private database subnets
- Internet Gateway
- NAT Gateway
- Route tables
- Security groups
- VPC peering
- Web EC2 instance
- Application EC2 instance
- Amazon RDS PostgreSQL
- Amazon ECR
- IAM role and instance profile

The application EC2 instance is located in a private subnet and uses the NAT Gateway for outbound Internet access.

The web EC2 instance runs Nginx and serves the static NimbusCart frontend.

Nginx reverse-proxies `/api/*` requests to the Express API running on the private application EC2 instance on port `8080`.

The Express API connects to Amazon RDS PostgreSQL using an encrypted SSL connection.

## Docker Deployment

The Express API is containerized using the Dockerfile located at:

`app/api/Dockerfile`

Terraform builds the Docker image and pushes it to Amazon ECR.

The private application EC2 instance authenticates to ECR using its IAM role and pulls the latest API image.

The API container receives configuration through environment variables including:

- Database host
- Database port
- Database username
- Database password
- Database name
- Database SSL configuration
- Application port

The container is configured to restart unless manually stopped.

## Terraform Remote Backend

Terraform remote state is stored in Amazon S3.

A separate bootstrap Terraform configuration creates the remote-state infrastructure before the main Terraform configuration uses it.

This avoids the bootstrapping problem where Terraform would otherwise require its backend infrastructure to exist before Terraform could create it.

## Terraform Outputs

The deployment provides outputs including:

- `app_private_ip`
- `db_endpoint`
- `frontend_url`
- `nat_gateway_public_ip`
- `peering_connection_id`

## Deployment Verification

The deployed API health endpoint successfully returned:

`HTTP/1.1 200 OK`

with:

`{"status":"ok"}`

The product endpoint was also successfully tested.

A Cloud Mouse product was stored in PostgreSQL and retrieved through the Express API:

`[{"id":1,"name":"Cloud Mouse","price":"29.99","stock":15}]`

The NimbusCart frontend successfully displayed the same product.

This verified the complete request path:

User -> Public Web EC2 -> Nginx -> Private App EC2 -> Express API -> VPC Peering -> Amazon RDS PostgreSQL

The final deployment therefore confirmed connectivity between all three application tiers.

---

# Task C - Conceptual Questions

## 1. Why must the DB subnet group span multiple Availability Zones?

AWS requires an RDS DB subnet group to contain subnets across multiple Availability Zones. This provides alternative placement options and supports high availability and Multi-AZ deployments.

## 2. VPC Peering vs Transit Gateway

VPC Peering provides direct private communication between VPCs and is suitable for a small architecture such as NimbusCart.

Transit Gateway provides a centralized networking hub and becomes more useful when many VPCs need to communicate.

## 3. How does the private App tier pull from ECR?

The private application EC2 instance uses its IAM role for AWS authentication and the NAT Gateway for outbound network connectivity.

Therefore:

`IAM role -> authentication`

`NAT Gateway -> Internet/ECR connectivity`

The EC2 instance can then authenticate to ECR and pull the Docker image.

## 4. Security Groups vs NACLs

Security groups are stateful, meaning response traffic for an allowed connection is automatically permitted.

Network ACLs are stateless, meaning both inbound and outbound traffic must be explicitly permitted.

A restrictive NACL could therefore allow PostgreSQL traffic on port 5432 but block the return traffic required by the application.

## 5. Why is local-exec discouraged?

Terraform cannot fully track side effects created by arbitrary `local-exec` commands.

In production, Docker image building and pushing would normally be handled by a CI/CD pipeline.

For this project, `local-exec` provides a simple way to automate building and pushing the API image to Amazon ECR.

## 6. Why is backend infrastructure bootstrapped separately?

Terraform cannot use an S3 backend before the S3 bucket exists.

Creating the backend using a separate bootstrap configuration solves this dependency problem.

The bootstrap configuration creates the remote-state infrastructure first, after which the main Terraform configuration can use the S3 backend.

---

# Final Result

NimbusCart was successfully deployed as a functional three-tier AWS application using Terraform and Docker.

The project demonstrates:

- Infrastructure as Code using Terraform
- Docker containerization
- Amazon ECR
- Amazon EC2
- Amazon RDS PostgreSQL
- Public and private subnets
- Internet Gateway
- NAT Gateway
- VPC peering
- Security groups
- Nginx reverse proxy
- Terraform remote state
- Bash automation
- End-to-end three-tier application connectivity

The final frontend successfully displayed product information stored in the PostgreSQL RDS database through the Dockerized Express API.
