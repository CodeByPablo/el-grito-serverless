# Configuración inicial de AWS y empaquetado de Lambda

provider "aws" {
  region = "us-east-1" # Cambia esto si usas otra región
}

# Empaquetar la función Python en un .zip

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../backend/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Configuración de Roles y Permisos IAM

resource "aws_iam_role" "lambda_exec" {
  name = "el_grito_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Creación del recurso AWS Lambda

resource "aws_lambda_function" "grito_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ElGritoFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
}

# Configuración de API Gateway HTTP (Más barato y rápido)

resource "aws_apigatewayv2_api" "grito_api" {
  name          = "ElGritoAPI"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

# Integración de API Gateway con Lambda

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.grito_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.grito_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.grito_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "post_grito" {
  api_id    = aws_apigatewayv2_api.grito_api.id
  route_key = "POST /grito"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.grito_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.grito_api.execution_arn}//*"
}

# Output de la URL para usar en tu frontend

output "api_gateway_url" {
  value       = "${aws_apigatewayv2_api.grito_api.api_endpoint}/grito"
  description = "Pega esta URL en tu archivo index.html"
}