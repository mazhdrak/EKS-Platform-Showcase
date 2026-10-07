output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "plan_role_arn" {
  description = "Set as GitHub variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Set as GitHub variable AWS_APPLY_ROLE_ARN."
  value       = aws_iam_role.apply.arn
}

output "ecr_push_role_arn" {
  description = "Set as GitHub variable AWS_ECR_PUSH_ROLE_ARN."
  value       = aws_iam_role.ecr_push.arn
}
