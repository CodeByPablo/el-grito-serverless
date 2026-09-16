provider "aws" {
  region = "us-east-1"
}

# 1. Empaquetar el código de Python automáticamente

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend"
  output_path = "${path.module}/lambda_function.zip"
}

# 2. Base de datos DynamoDB para el contador global

resource "aws_dynamodb_table" "gritos_table" {
  name         = "GritosTotales"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# 3. Rol IAM y permisos para la Lambda

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_grito_role"

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

# Permiso básico para escribir logs en CloudWatch

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permiso específico para que la Lambda lea y escriba en DynamoDB

resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:UpdateItem",
        "dynamodb:GetItem"
      ]
      Resource = aws_dynamodb_table.gritos_table.arn
    }]
  })
}

# 4. Creación del recurso AWS Lambda

resource "aws_lambda_function" "grito_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ElGritoFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.gritos_table.name
    }
  }
}

# 5. Configuración de API Gateway HTTP (Más barato y rápido)

resource "aws_apigatewayv2_api" "grito_api" {
  name          = "ElGritoAPI"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # Para producción usarías tu dominio exacto de GitHub Pages
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.grito_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.grito_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.grito_lambda.invoke_arn
  payload_format_version = "2.0"
}

# Ruta POST para recibir el grito

resource "aws_apigatewayv2_route" "post_grito" {
  api_id    = aws_apigatewayv2_api.grito_api.id
  route_key = "POST /grito"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Ruta GET para cargar el contador al entrar a la web

resource "aws_apigatewayv2_route" "get_grito" {
  api_id    = aws_apigatewayv2_api.grito_api.id
  route_key = "GET /grito"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Permiso para que API Gateway invoque la Lambda

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.grito_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.grito_api.execution_arn}//*"
}

# 6. Imprimir la URL final en la consola al terminar

output "api_gateway_url" {
  value = "${aws_apigatewayv2_api.grito_api.api_endpoint}/grito"
}