
# Create a instance
# resource "aws_instance" "example" {
#   ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
#   instance_type = terraform.workspace == "prod" ? "t3.large" : "t3.micro"
# 
#   tags = {
#     Name = var.devInstanceName
#   }
# }

# Create a VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "dev-vpc-01"
  }
}

# 2. Local Variables
locals {
  function_name = "hotel-add-hotel"
  src_dir       = "${path.module}/HotelMan_HotelAdmin"
  publish_dir   = "${path.module}/HotelMan_HotelAdmin/bin/Release/net8.0/linux-x64/publish"
  output_zip    = "${path.module}/hotel-addhotel-function.zip"
}

# 3. Automate .NET Build and Publish via local-exec
resource "null_resource" "build_dotnet_lambda" {
  triggers = {
    always_run = timestamp() # Ensures it recompiles every time you apply
  }

  provisioner "local-exec" {
    command     = "dotnet publish -c Release --runtime linux-x64 --self-contained false"
    working_dir = local.src_dir
  }
}

# 4. Zip the published files
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.publish_dir
  output_path = local.output_zip

  depends_on = [null_resource.build_dotnet_lambda]
}

# 5. IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# 6. Attach Basic Execution Policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 7. Provision the AWS Lambda Function
resource "aws_lambda_function" "dotnet_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = local.function_name
  role             = aws_iam_role.lambda_role.arn
  runtime          = "dotnet8"
  timeout          = 15
  memory_size      = 256

  # Format: AssemblyName::Namespace.ClassName::MethodName
  handler = "HotelMan_HotelAdmin::HotelMan_HotelAdmin.HotelAdmin::AddHotel" 

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    data.archive_file.lambda_zip
  ]
}
