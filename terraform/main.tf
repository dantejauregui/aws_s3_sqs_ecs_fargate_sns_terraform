terraform {
  required_version = ">= 1.7.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

module "input_s3" {
  source = "./modules/input_s3"
}

module "vpc_for_ecs" {
  source = "./modules/vpc_for_ecs"
}

# module "loadBalancer_for_ecs" {
#   source = "./modules/loadBalancer_for_ecs"

#   vpc_id = module.vpc_for_ecs.vpc_id
#   security_group_vpc = module.vpc_for_ecs.security_group_vpc
#   subnet1 = module.vpc_for_ecs.subnet1
#   subnet2 = module.vpc_for_ecs.subnet2
# }

module "ecs_fargate" {
  source = "./modules/ecs_fargate"

  subnet1 = module.vpc_for_ecs.subnet1
  subnet2 = module.vpc_for_ecs.subnet2
  # loadBalancer_listener_for_ecs = module.loadBalancer_for_ecs
  # aws_lb_target_group_arn = module.loadBalancer_for_ecs.aws_lb_target_group_arn
  security_group_vpc = module.vpc_for_ecs.security_group_vpc
}

module "eventBridge" {
  source = "./modules/eventBridge"

  image_processing_queue_ARN = module.sqs.image_processing_queue_ARN
  image_processing_queue_id = module.sqs.image_processing_queue_id
}

module "sns" {
  source = "./modules/sns"
}

module "sqs" {
  source = "./modules/sqs"
}