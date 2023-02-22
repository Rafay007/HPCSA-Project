terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create the public subnet
resource "aws_subnet" "public_subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.vpc.id
}

# Create the security group to allow inbound SSH and HTTP traffic
resource "aws_security_group" "security_group" {
  name_prefix = "ecs-cluster"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

# Create the EC2 instances
resource "aws_instance" "ecs_instances" {
  count         = 3
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.2xlarge"
  key_name      = "my_keypair"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [
    aws_security_group.security_group.id,
  ]
  user_data = <<-EOF
              #!/bin/bash
              # Install the ECS agent
              echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
              yum update -y
              yum install -y aws-cli
              amazon-linux-extras install -y ecs
              systemctl enable --now ecs
              EOF
}

# Create a task definition for the shell script
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "my-task"
  container_definitions    = jsonencode([{
    name      = "my-container"
    image     = "my-docker-image"
    cpu       = 512
    memory    = 1024
    essential = true
    command   = ["/bin/bash", "/tmp/all_in_one.sh"]
  }])
  requires_compatibilities = ["EC2"]
}

# Create a service to run the task on the cluster
resource "aws_ecs_service" "ecs_service" {
  name            = "my-service"
  cluster         = aws_ecs_cluster.ecs_cluster.arn
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    security_groups = [aws_security_group.security_group.id]
    subnets         = [aws_subnet.public_subnet.id]
  }
}
