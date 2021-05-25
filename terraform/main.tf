/*
Will deploy a docker container:
- into two sydney regions
- and puts a load balancer in front of it

The steps are as follows:
- Create an ECR
- Create a new cluster
- Create a new task
- Create a service (a group of  tasks)

After you run this code, you will not have a deployed contaienr, because you haven't uploaded
the container to AWS. It will create the ECR entry for you to upload it to. So you need to upload
the container by following the commands at: 
https://ap-southeast-2.console.aws.amazon.com/ecr/repositories?region=ap-southeast-2 - click repo
then click view commands. 

Can you type `terraform apply` again but not needed. AWS is will detect the image and go from there.

`terraform destroy` will delete all changes, including your uploaded Docker container

*/

provider "aws" {
  version = "~> 3.0"
  region  = "ap-southeast-2"
}

# ECR entry
# Creating but more so for referencing, because you need to upload the image here
resource "aws_ecr_repository" "pollute_api_ecr_repo" {
  name = "pollute_api_ecr_repo"
}

### Create new cluster
#######################################################

# Creating a new cluster
resource "aws_ecs_cluster" "pollute_api_cluster" {
  name = "pollute_api_cluster" # Naming the cluster
}

### Creating the task (how the container should be run)
#######################################################

resource "aws_ecs_task_definition" "pollute_api_task" {
  family                   = "pollute-api-task" # Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "pollute-api-task",
      "image": "${aws_ecr_repository.pollute_api_ecr_repo.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "hostPort": 8000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# needs AssumeRole to be table ot execute the defined task
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

### Creating the service
#######################################################

resource "aws_ecs_service" "pollute_api_service" {
  name            = "pollute-api-service"                        # Naming our first service
  cluster         = aws_ecs_cluster.pollute_api_cluster.id       # Referencing our created Cluster
  task_definition = aws_ecs_task_definition.pollute_api_task.arn # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 2 # Setting the number of containers we want deployed to 2

  # link load balancer target groups to the service
  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our target group
    container_name   = aws_ecs_task_definition.pollute_api_task.family
    container_port   = 8000 # Specifying the container port
  }

  network_configuration {
    subnets          = [aws_default_subnet.default_subnet_a.id, aws_default_subnet.default_subnet_b.id]
    assign_public_ip = true                                           # Providing our containers with public IPs
    security_groups  = [aws_security_group.service_security_group.id] # add sec group
  }

  depends_on = [aws_alb.application_load_balancer]
}

# security group for the ECS service
resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  egress {
    from_port   = 0             # Allowing any incoming port
    to_port     = 0             # Allowing any outgoing port
    protocol    = "-1"          # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

### VPC Configuration - availability zones and subnets to deploy to
#######################################################

# Providing a reference to our default VPC
resource "aws_default_vpc" "default_vpc" {
}

# Providing a reference to our default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "ap-southeast-2a" # sydney 1
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "ap-southeast-2b" # sydney 2
}

### Put a load balancer in front
#######################################################

resource "aws_alb" "application_load_balancer" {
  name               = "pollute-api-lb-tf" # Naming our load balancer
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    aws_default_subnet.default_subnet_a.id,
    aws_default_subnet.default_subnet_b.id
  ]
  # Referencing the security group
  security_groups = [aws_security_group.load_balancer_security_group.id]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80 # Allowing traffic in from port 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0             # Allowing any incoming port
    to_port     = 0             # Allowing any outgoing port
    protocol    = "-1"          # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

### Create target groups for LB
### Each target group is used to route requests to one or more registered targets (our containers)
#######################################################

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id # Referencing the default VPC
  health_check {
    matcher = "200,301,302"
    path    = "/"
  }
  //or add depends on here
  depends_on = [aws_alb.application_load_balancer]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.arn # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our tagrte group
  }
}
