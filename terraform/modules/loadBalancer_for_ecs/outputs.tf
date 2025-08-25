output "aws_alb_listener" {
  description = "Security group of vpc"
  value       = aws_alb_listener.Listener.id
}

output "aws_lb_target_group_arn" {
  description = "Security group of vpc"
  value       = aws_lb_target_group.TG.arn
}