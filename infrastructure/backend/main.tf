provider "aws" {
  region = "eu-west-1"
}

# Define the Lambda function code
data "archive_file" "lambda_function_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function/lambda_function.zip" # Output path for the zip file
  source_dir  = "${path.module}/lambda_function"                     # Directory containing Lambda function code
}

# Create DynamoDB table
resource "aws_dynamodb_table" "table" {
  name         = "crc-fbrpinto-dynamodb-tf"
  hash_key     = "id"
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
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : { "Service" : "lambda.amazonaws.com" },
      "Action" : "sts:AssumeRole"
    }]
  })
}

# Attach policy to IAM role
resource "aws_iam_policy_attachment" "lambda_execution" {
  name       = "lambda-policy"
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

# Create API Gateway V2 API
resource "aws_apigatewayv2_api" "example" {
  name          = "crc-fbrpinto-api_gw-tf"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
  }
}

# Define API Gateway V2 integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.example.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.example.invoke_arn
}

# Define API Gateway V2 route
resource "aws_apigatewayv2_route" "visitors" {
  api_id    = aws_apigatewayv2_api.example.id
  route_key = "POST /visitors"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Deploy API Gateway
resource "aws_apigatewayv2_stage" "example" {
  api_id = aws_apigatewayv2_api.example.id
  name   = "dev"
}

# Output the endpoint URL of the deployed API
output "api_endpoint_url" {
  value = aws_apigatewayv2_api.example.api_endpoint
}
