locals {
  prefix = "hb_fap"
  
}
# ---------------------------------------------------------------------------------------------------------------------
# SNS TOPIC
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sns_topic" "results_updates" {
  name = "${local.prefix}-sns-topic"
}


# ---------------------------------------------------------------------------------------------------------------------
# SQS QUEUE 1
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sqs_queue" "results_updates_queue" {
  name                       = "${local.prefix}-sqs1-queue"
  //redrive_policy             = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.results_updates_dl_queue.arn}\",\"maxReceiveCount\":5}"
  visibility_timeout_seconds = 300

  tags = {
    Environment = "dev"
  }
}

# resource "aws_sqs_queue" "results_updates_dl_queue" {
#   name = "${local.prefix}-sqs1-dl-queue"
# }

# ---------------------------------------------------------------------------------------------------------------------
# SQS QUEUE 2
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sqs_queue" "results_updates_queue2" {
  name                       = "${local.prefix}-sqs2-queue"
  //redrive_policy             = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.results_updates_dl_queue2.arn}\",\"maxReceiveCount\":5}"
  visibility_timeout_seconds = 300

  tags = {
    Environment = "dev"
  }
}

# resource "aws_sqs_queue" "results_updates_dl_queue2" {
#   name = "${local.prefix}-sqs2-dl-queue"
# }

# ---------------------------------------------------------------------------------------------------------------------
# SQS POLICY 1
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sqs_queue_policy" "results_updates_queue_policy" {
  queue_url = aws_sqs_queue.results_updates_queue.id

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Sid": "__owner_statement",
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "SQS:*",
      "Resource": "${aws_sqs_queue.results_updates_queue.arn}"
    }
  ]
}
POLICY
}
# ---------------------------------------------------------------------------------------------------------------------
# SQS POLICY 2
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sqs_queue_policy" "results_updates_queue_policy2" {
  queue_url = aws_sqs_queue.results_updates_queue2.id

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Sid": "__owner_statement",
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "SQS:*",
       "Resource": "${aws_sqs_queue.results_updates_queue2.arn}"
    }
  ]
}
POLICY
}


# ---------------------------------------------------------------------------------------------------------------------
# SNS SUBSCRIPTION 1
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "results_updates_sqs_target" {
  topic_arn = aws_sns_topic.results_updates.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.results_updates_queue.arn
  filter_policy = "{ \"account\": [\"1\"]}"
}
# ---------------------------------------------------------------------------------------------------------------------
# SNS SUBSCRIPTION 2
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "results_updates_sqs_target2" {
  topic_arn = aws_sns_topic.results_updates.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.results_updates_queue2.arn
  filter_policy = "{ \"account\": [\"2\"]}"
}

# ---------------------------------------------------------------------------------------------------------------------
# Dynamodb
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_dynamodb_table" "ddbtable1" {
  name             = "fap-account1"
  hash_key         = "Id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "Id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "ddbtable2" {
  name             = "fap-account2"
  hash_key         = "Id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "Id"
    type = "S"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA ROLE & POLICIES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "lambda_role" {
  name               = "${local.prefix}-LambdaRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_logs_policy" {
  name   = "${local.prefix}-LambdaRolePolicy"
  role   = aws_iam_role.lambda_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_sqs_policy" {
  name   = "${local.prefix}-AllowSQSPermissions"
  role   = aws_iam_role.lambda_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:ChangeMessageVisibility",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy" "lambda_role_dynamodb_policy" {
  name   = "${local.prefix}-AllowDynamoDbPermissions"
  role   = aws_iam_role.lambda_role.id
  policy = <<EOF
{  
  "Version": "2012-10-17",
  "Statement":[{
    "Effect": "Allow",
    "Action": [
     "dynamodb:BatchGetItem",
     "dynamodb:GetItem",
     "dynamodb:Query",
     "dynamodb:Scan",
     "dynamodb:BatchWriteItem",
     "dynamodb:PutItem",
     "dynamodb:UpdateItem"
    ],
    "Resource": "*"
   }
  ]
}
EOF
}
# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lambda_function" "results_updates_lambda" {
  filename         = "${path.module}/lambda/example.zip"
  function_name    = "${local.prefix}-sqs-trigger"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"

  # environment {
  #   variables = {
  #     foo = "bar"
  #   }
  # }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA EVENT SOURCE 1
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "results_updates_lambda_event_source" {
  event_source_arn = aws_sqs_queue.results_updates_queue.arn
  enabled          = true
  function_name    = aws_lambda_function.results_updates_lambda.arn
  batch_size       = 1
}
# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA EVENT SOURCE 2
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "results_updates_lambda_event_source2" {
  event_source_arn = aws_sqs_queue.results_updates_queue2.arn
  enabled          = true
  function_name    = aws_lambda_function.results_updates_lambda.arn
  batch_size       = 1
}
