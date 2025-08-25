variable "subnet1" {}
variable "subnet2" {}
variable "loadBalancer_listener_for_ecs" {}
variable "aws_lb_target_group_arn" {}
variable "security_group_vpc" {}

resource "aws_ecs_cluster" "ECS" {
  name = "my-cluster"

  tags = {
    Name = "my-new-cluster"
  }
}

resource "aws_ecs_service" "ECS-Service" {
  name                               = "my-service"
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  cluster                            = aws_ecs_cluster.ECS.id
  task_definition                    = aws_ecs_task_definition.TD.arn
  scheduling_strategy                = "REPLICA"
  desired_count                      = 2
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  depends_on                         = [var.loadBalancer_listener_for_ecs, aws_iam_role.ecs_execution_role]


  load_balancer {
    target_group_arn = var.aws_lb_target_group_arn
    container_name   = "main-container"
    container_port   = 80
  }


  network_configuration {
    assign_public_ip = true
    security_groups  = [var.security_group_vpc]
    subnets          = [var.subnet1, var.subnet2]
  }
}


resource "aws_ecs_task_definition" "TD" {
  family                   = "nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048

  execution_role_arn = aws_iam_role.ecs_execution_role.arn  # IAM defined below for ECS agent (pull image, logs)
  # task_role_arn      = aws_iam_role.ecs_task_role.arn       # IAM defined below for our app (SQS/S3)


  container_definitions = jsonencode([
    {
      name      = "main-container"
      image     = "gomurali/exp-app-1:2"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}


# data "aws_ecs_task_definition" "TD" {
#   task_definition = aws_ecs_task_definition.TD.family
# }


# 1. IAM Execution role (image pulls + logs):
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# 2. IAM Task role (your app: SQS + S3):
# resource "aws_iam_role" "ecs_task_role" {
#   name = "ecs-task-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect: "Allow",
#       Principal = { Service = "ecs-tasks.amazonaws.com" },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy" "ecs_task_permissions" {
#   name = "ecs-task-permissions"
#   role = aws_iam_role.ecs_task_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement: [
#       {
#         Effect: "Allow",
#         Action: ["sqs:ReceiveMessage","sqs:DeleteMessage","sqs:GetQueueAttributes"],
#         Resource: aws_sqs_queue.image_processing_queue.arn
#       },
#       {
#         Effect: "Allow",
#         Action: ["s3:GetObject","s3:PutObject"],
#         Resource: [
#           "arn:aws:s3:::image-upload-bucket/uploads/*",
#           "arn:aws:s3:::image-upload-bucket/thumbnails/*"
#         ]
#       }
#     ]
#   })
# }
