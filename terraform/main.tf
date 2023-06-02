# 테라폼 제공자
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# 리전 및 계정정보 불러오기
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


## 람다

# 람다 로그를 저장할 로그그룹 생성
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/hello"
  retention_in_days = 1
}

# 람다에 부여할 IAM 역할 생성
resource "aws_iam_role" "lambda" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  inline_policy {
    name   = "cloudwatch_logs"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "${aws_cloudwatch_log_group.lambda.arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
  }
}

# 소스코드
data "archive_file" "hello" {
  type        = "zip"
  source_file = "../source/app.py"
  output_path = "lambda_function_payload.zip"
}

# 람다 함수
resource "aws_lambda_function" "hello" {
  filename      = "lambda_function_payload.zip"
  function_name = "hello"
  role          = aws_iam_role.lambda.arn
  handler       = "app.lambda_handler"

  source_code_hash = data.archive_file.hello.output_base64sha256

  runtime = "python3.10"
}

## Cognito

# Cognito 사용자 풀 생성
resource "aws_cognito_user_pool" "demo" {
  name = "demo-userpool"
}

# 위에서 생성한 사용자 풀을 사용할 App 클라이언트
resource "aws_cognito_user_pool_client" "demo" {
  name         = "demo"
  user_pool_id = aws_cognito_user_pool.demo.id
  
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Cognito 유저 
resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.demo.id
  username     = "test-user"
  password     = "Asdf!234"
  attributes = {
    email          = "test@example.com"
    email_verified = true
  }
}



## API 게이트웨이

# API 게이트웨이 로그를 저장할 로그그룹 생성
resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/hello"
  retention_in_days = 1
}

# API 게이트웨이에 부여할 IAM 역할 생성
resource "aws_iam_role" "apigateway" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  inline_policy {
    name   = "cloudwatch_logs"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "${aws_cloudwatch_log_group.apigateway.arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
  }
}

# REST API 게이트웨이
resource "aws_api_gateway_rest_api" "demo_api" {
  name = "demo-api"
}

# API 게이트웨이 인증 
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  provider_arns = [aws_cognito_user_pool.demo.arn]
}

# REST API 리소스
resource "aws_api_gateway_resource" "hello" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  parent_id   = aws_api_gateway_rest_api.demo_api.root_resource_id
  path_part   = "hello"
}

# 위에서 생성한 리소스에 메소드 추가
resource "aws_api_gateway_method" "hello_get" {
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  resource_id   = aws_api_gateway_resource.hello.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# 위에서 생성한 메소드에 람다 연동
resource "aws_api_gateway_integration" "hello_get" {
  rest_api_id             = aws_api_gateway_rest_api.demo_api.id
  resource_id             = aws_api_gateway_resource.hello.id
  http_method             = aws_api_gateway_method.hello_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello.invoke_arn
}

# API 게이트웨이에 람다 함수를 실행할수 있는 권한 부여
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*/*/*"
}

# API 배포 생성
resource "aws_api_gateway_deployment" "demo_api" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.hello.id,
      aws_api_gateway_method.hello_get.id,
      aws_api_gateway_integration.hello_get.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API 배포 스테이지 생성
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.demo_api.id
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  stage_name    = "dev"
}

# Output
output "aws_cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.demo.id
}

output "api_invoke_url" {
  value = "${aws_api_gateway_stage.dev.invoke_url}${aws_api_gateway_resource.hello.path}"
}