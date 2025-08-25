# Terraform Part:
Inside the `Terraform folder`, you can run the AWS Infrastructure using:
```
terraform init
terraform plan
terraform apply
```

And to destroy:
```
terraform destroy
```


# Architecture
Initially was planned to use ALB load balancer, but now will be omited/commented due to:
**This worker doesn’t accept inbound HTTP**: for a queue-driven worker (poll SQS → read/write S3), an ALB isn’t needed because nothing on the internet (or your VPC) needs to call into the task. The task only makes outbound calls (to SQS/S3). So we can drop the ALB wiring and simplify.