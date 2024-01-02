provider "aws" {
  region = var.region
  profile = var.profile
}

resource "aws_iam_role" "lambda_role" {
  name               = "my-lambda-role-tf"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
{
"Action" : "sts:AssumeRole",
"Principal" : {
"Service" : "lambda.amazonaws.com"
},
"Effect" : "Allow",
"Sid"    : ""
}
]
}
EOF
}


resource "aws_iam_role_policy" "my-lambda-tf" {
  name        = "lambda-policy"
#   path        = "/"
#   description = "my lambda policy"
  role = aws_iam_role.lambda_role.id

  policy = <<EOF
{
"Version"   : "2012-10-17",
"Statement" : [
{
"Effect"   : "Allow",
"Action"   : ["dynamodb:*", "s3:*"],
"Resource" : "arn:aws:logs:*:*:*"
}
]
}
EOF
}

# resource "aws_iam_role_policy_attachment" "my_lambda_policy_attachment" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = aws_iam_policy.my-lambda-tf.arn
# }

data "archive_file" "zip_py_code" {
  type        = "zip"
  source_dir  = "${path.module}/python/"
  output_path = "${path.module}/python/hello-python.zip"
}


resource "aws_lambda_function" "tf_aws_lambda_fn" {
  filename      = "${path.module}/python/hello-python.zip"
  function_name = "tf-aws-lambda-fn"
  role          = aws_iam_role.lambda_role.arn
  handler       = "hello-python.lambda_handler"
  runtime       = "python3.8"
  #depends_on    = [aws_iam_role_policy_attachment.my_lambda_policy_attachment]
}

resource "aws_s3_bucket" "tf_lambda_bkt" {
  bucket = "tf-lambda-bkt"

  tags = {
    Name = "tf-lambda-bkt"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_ownership_controls" "lambda_own" {
  bucket = aws_s3_bucket.tf_lambda_bkt.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.tf_lambda_bkt.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "s3_bkt_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.lambda_own,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.tf_lambda_bkt.id
  acl    = "public-read"
}

resource "aws_dynamodb_table" "tf_aws_lambda_dynamodb_table" {
  name           = "newtable"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "unique"

  attribute {
    name = "unique"
    type = "S"
  }

  tags = {
    Name        = "dynamodb-table-1"
    Environment = "Dev"
  }
}

# resource "aws_lambda_event_source_mapping" "trigger_s3" {
#   event_source_arn  = aws_s3_bucket.tf_lambda_bkt.arn
#   function_name     = aws_lambda_function.tf_aws_lambda_fn.arn
#   starting_position = "LATEST"
# }

resource "aws_lambda_permission" "test" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tf_aws_lambda_fn.arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.tf_lambda_bkt.id}"
}

resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.tf_lambda_bkt.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.tf_aws_lambda_fn.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]

  }
}

