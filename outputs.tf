output "tf_aws_role_op" {
  value = aws_iam_role.lambda_role.name
}

output "tf_aws_role_arn_op" {
  value = aws_iam_role.lambda_role.arn
}

output "tf_logging_arn_op" {
  value = aws_iam_role_policy.my-lambda-tf.name
}