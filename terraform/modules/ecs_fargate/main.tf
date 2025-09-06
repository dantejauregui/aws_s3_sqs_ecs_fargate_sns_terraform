variable "subnet1" {}
variable "subnet2" {}
variable "security_group_vpc" {}
variable "image_processing_queue_ARN" {}
variable "image_upload_bucket_arn" {}
variable "image_upload_bucket_name" {}
variable "image_processing_queue_url" {}
variable "sns_topic_name" {}
variable "sns_topic_ARN" {}


resource "aws_ecs_cluster" "ECS" {
  name = "my-cluster"

  tags = {
    Name = "my-new-cluster"
  }
}

# CloudWatch Logs (so you can see Docker Container logs)
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/image-processor"
  retention_in_days = 14
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
  depends_on                         = [aws_iam_role.ecs_execution_role]


  # load_balancer {
  #   target_group_arn = var.aws_lb_target_group_arn
  #   container_name   = "main-container"
  #   container_port   = 80
  # }


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

  execution_role_arn = aws_iam_role.ecs_execution_role.arn # IAM defined below for ECS agent (pull image, logs)
  task_role_arn      = aws_iam_role.ecs_task_role.arn      # IAM defined below for our app (SQS/S3)


  container_definitions = jsonencode([
    {
      name      = "main-container"
      image     = "dantej/image-processor:1.0.1"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]

      # Env. Variables for Python Docker Container:
      environment = [
        { "name" : "QUEUE_URL", "value" : var.image_processing_queue_url },
        { "name" : "BUCKET", "value" : var.image_upload_bucket_name },
        { "name" : "UPLOADS_PREFIX", "value" : "uploads/" },
        { "name" : "THUMB_PREFIX", "value" : "thumbnails/" },
        { "name" : "THUMB_MAX_WIDTH", "value" : "512" },
        { "name" : "SNS_TOPIC_ARN", "value" : var.sns_topic_ARN } # for SNS notification
      ]

      # So Cloudwatch can get Docker Container logs from ECS using "awslogs", which is the CloudWatch Logs log driver:
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name,
          awslogs-region        = "eu-central-1",
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}


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


# 2. IAM Task role (your app: SQS + S3 + etc.):
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect : "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_permissions" {
  name = "ecs-task-permissions"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Resource : var.image_processing_queue_ARN
      },
      {
        Effect : "Allow",
        Action : ["s3:ListBucket"],
        Resource : var.image_upload_bucket_arn,
        Condition : {
          "StringLike" : {
            "s3:prefix" : ["uploads/*", "thumbnails/*"]
          }
        }
      },
      {
        Effect : "Allow",
        Action : ["s3:GetObject"],
        Resource : [
          "${var.image_upload_bucket_arn}/uploads/*",
          "${var.image_upload_bucket_arn}/thumbnails/*"
        ]
      },
      {
        Effect : "Allow",
        Action : ["s3:PutObject"],
        Resource : "${var.image_upload_bucket_arn}/thumbnails/*"
      },
      {
        "Effect" : "Allow",
        "Action" : ["sns:Publish"],
        "Resource" : var.sns_topic_ARN
      }

    ]
  })
}
