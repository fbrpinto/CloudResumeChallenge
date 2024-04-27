provider "aws" {
  region = "eu-west-1"
}

# Define the Lambda function code
data "archive_file" "lambda_function_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function/lambda_function.zip"  # Output path for the zip file
  source_dir  = "${path.module}/lambda_function"     # Directory containing Lambda function code
}

# Create DynamoDB table
resource "aws_dynamodb_table" "table" {
  name           = "crc-fbrpinto-dynamodb-tf"
  hash_key       = "id"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "id"
    type = "S"
  }
}

# Create Lambda function
resource "aws_lambda_function" "example" {
  filename      = data.archive_file.lambda_function_zip.output_path
  function_name = "crc-fbrpinto-lambda-tf"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
}

# Define IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  })
}

# Attach policy to IAM role
resource "aws_iam_policy_attachment" "lambda_execution" {
  name = "lambda-policy"
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  roles      = [aws_iam_role.lambda_role.name]
}

# Allow API Gateway to invoke Lambda function
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "apigateway.amazonaws.com"
}

# Create API Gateway REST API
resource "aws_api_gateway_rest_api" "example" {
  name        = "crc-fbrpinto-api_gw-tf"
  description = "API for Lambda function"
}

# Define API Gateway resource
resource "aws_api_gateway_resource" "test" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "test"
}

# Define API Gateway method and associate it with the resource
resource "aws_api_gateway_method" "test" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.test.id
  http_method   = "GET"
  authorization = "NONE"
}

# Create a mock integration for the testing method
resource "aws_api_gateway_integration" "testing" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.test.id
  http_method             = aws_api_gateway_method.test.http_method
  integration_http_method = "GET"
  type                    = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  # response_templates = {
  #   "application/json" = "{\"message\": \"test ok\"}"
  # }
}

# Define API Gateway resource
resource "aws_api_gateway_resource" "visitors" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "visitors"
}

# Define API Gateway method and associate it with the resource
resource "aws_api_gateway_method" "visitors" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.visitors.id
  http_method   = "POST"
  authorization = "NONE"
}


# Integrate API Gateway with Lambda function
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.visitors.id
  http_method             = aws_api_gateway_method.visitors.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.example.invoke_arn
}

# # Create a custom domain name for the API Gateway
# resource "aws_api_gateway_domain_name" "custom_domain" {
#   domain_name              = "api.fbrpinto.com"
#   certificate_arn          = "arn:aws:acm:us-east-1:984144078054:certificate/8a06f51e-617c-45a5-8075-1a65624378a4"
#   security_policy          = "TLS_1_2"
# }

# # Create a base path mapping for the custom domain
# resource "aws_api_gateway_base_path_mapping" "custom_domain_mapping" {
#   api_id      = aws_api_gateway_rest_api.example.id
#   domain_name = aws_api_gateway_domain_name.custom_domain.domain_name
#   stage_name  = "dev"
#   base_path   = "api"
# }

# Deploy API Gateway
resource "aws_api_gateway_deployment" "example" {
  depends_on = [aws_lambda_permission.apigw]
  rest_api_id = aws_api_gateway_rest_api.example.id
  stage_name = "dev"
}

# Output the endpoint URL of the deployed API
output "api_endpoint_url" {
  value = aws_api_gateway_deployment.example.invoke_url
}