provider "aws" {
  region = "us-east-1"  # Change this to your desired AWS region
}

terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "< 5.31.0"
    }
  }
}

resource "aws_vpc" "ruby_app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "ruby-app-vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.ruby_app_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"  # Replace with your desired availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.ruby_app_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"  # Replace with your desired availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_route_table" "ruby_route_table" {
  vpc_id = aws_vpc.ruby_app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ruby_app_igw.id
  }

  tags = {
    Name = "example"
  }
}

resource "aws_internet_gateway" "ruby_app_igw" {
  vpc_id = aws_vpc.ruby_app_vpc.id
}

resource "aws_route" "public_subnet_1_route" {
  route_table_id         = aws_route_table.ruby_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ruby_app_igw.id
}

resource "aws_route" "public_subnet_2_route" {
  route_table_id         = aws_route_table.ruby_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ruby_app_igw.id
}

# Create an ECS cluster
resource "aws_ecs_cluster" "ruby_app_cluster" {
  name = "ruby-app-cluster"
}

# Create an ECR repository
resource "aws_ecr_repository" "ruby_app_repo" {
  name = "ruby-app-repo"
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com",
        },
      },
    ],
  })
}

# Attach AmazonECSTaskExecutionRolePolicy to the ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

# Create a task definition for ECS
resource "aws_ecs_task_definition" "ruby_app_task" {
  family                   = "ruby-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "ruby-app-container"
    image = aws_ecr_repository.ruby_app_repo.repository_url

    command = ["bundle", "install", "rails", "s", "-b", "0.0.0.0"]

    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
  }])
}

resource "aws_ecs_task_definition" "ruby_app_task" {
  family                   = "ruby-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "ruby-app-container"
    image = aws_ecr_repository.ruby_app_repo.repository_url

    entryPoint = ["/bin/bash", "-c"]
    command    = ["git clone https://github.com/StrongMind/frozen-desserts.git && cd frozen-desserts && bundle install && rails s -b 0.0.0.0"]

    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
  }])
}

# Create a security group allowing inbound traffic on port 3000
resource "aws_security_group" "ruby_app_security_group" {
  name        = "ruby-app-security-group"
  description = "Security group for the Ruby app"
  vpc_id      = aws_vpc.ruby_app_vpc.id
  
  ingress {
    from_port = 3000
    to_port   = 3000
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow traffic from any IP (customize as needed)
  }
}

# Create an Application Load Balancer (ALB)
/*resource "aws_lb" "ruby_app_lb" {
  name               = "ruby-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ruby_app_security_group.id]
  subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false

  enable_http2        = true
  enable_cross_zone_load_balancing = true
  idle_timeout        = 400
  //enable_deletion_protection = false
}

# Create a listener for the ALB
resource "aws_lb_listener" "ruby_app_listener" {
  load_balancer_arn = aws_lb.ruby_app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "OK"
    }
  }
}

# Create a target group for the ECS service
resource "aws_lb_target_group" "ruby_app_target_group" {
  name     = "ruby-app-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.ruby_app_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = 3000
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "ruby_app_attachment" {
  target_group_arn = aws_lb_target_group.ruby_app_target_group.arn
  target_id        = aws_ecs_service.ruby_app_service.id
}*/


# Attach the ECS service to the ALB target group
resource "aws_ecs_service" "ruby_app_service" {
  name            = "ruby-app-service"
  cluster         = aws_ecs_cluster.ruby_app_cluster.id
  task_definition = aws_ecs_task_definition.ruby_app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups = [aws_security_group.ruby_app_security_group.id]
  }

  /*load_balancer {
    target_group_arn = aws_lb_target_group.ruby_app_target_group.arn
    container_name   = "ruby-app-container"
    container_port   = 3000
  }*/
}


/*resource "aws_db_instance" "my_database" {
  identifier           = "my-database"
  engine               = "mysql"  # or "postgresql"
  instance_class       = "db.t2.micro"
  username             = "db_user"
  password             = "db_password"
  allocated_storage    = 20
  storage_type         = "gp2"
  publicly_accessible  = false
  db_subnet_group_name = module.vpc.default_db_subnet_group_name
}*/
