variable "vpc_id" {}
variable "security_group_vpc" {}
variable "subnet1" {}
variable "subnet2" {}

resource "aws_lb" "LB" {
  name               = "LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_vpc]
  subnets            = [var.subnet1, var.subnet2]

  tags = {
    Name = "LB"
  }
}

resource "aws_alb_listener" "Listener" {
  load_balancer_arn = aws_lb.LB.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.TG.id
    type             = "forward"
  }
}


resource "aws_lb_target_group" "TG" {
  name        = "TG"
  port        = "80"
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  tags = {
    Name = "TG"
  }
}