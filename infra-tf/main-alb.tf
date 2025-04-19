# Provider and basic setup
provider "aws" {
  region = "ap-south-1" # Update the region as needed
}

# VPC and Subnets
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-south-1a"
}


resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-south-1b" # Replace with the desired AZ
  map_public_ip_on_launch = false
}

# Internet Gateway for Public Access
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}


# NAT Gateway for Private Subnet
resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.my_igw] # Ensure IGW is created before Elastic IP
}

resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
  }
}

resource "aws_route_table_association" "private_subnet_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Allow traffic from within the VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    protocol = "HTTP"
    path     = "/"   # Specify the endpoint for health checks
    interval = 30          # Time between health checks (in seconds)
    timeout  = 5           # Maximum time to wait for a health check response
    healthy_threshold = 2  # Number of consecutive successes for a target to be considered healthy
    unhealthy_threshold = 2 # Number of consecutive failures for a target to be considered unhealthy
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# EC2 Instances
resource "aws_instance" "my_instance" {
  count           = 2
  ami             = "ami-06b6e5225d1db5f46"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = false
  user_data = templatefile("${path.module}/bootstrap.sh", {})
  depends_on = [ aws_nat_gateway.my_nat_gateway ]
}


# Target Group Attachment
resource "aws_lb_target_group_attachment" "ec2_attachment" {
  count = 2
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.my_instance[count.index].id
  port             = 80 # The port the EC2 instance is listening on
  depends_on = [ aws_instance.my_instance ]
}

# API Gateway VPC Link
resource "aws_apigatewayv2_vpc_link" "my_vpc_link" {
  name        = "my-vpc-link"
  subnet_ids  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  security_group_ids = [aws_security_group.alb_sg.id]
}

# API Gateway Integration
resource "aws_apigatewayv2_api" "my_api" {
  name          = "my-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "alb_integration" {
  api_id             = aws_apigatewayv2_api.my_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = aws_lb_listener.http_listener.arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.my_vpc_link.id
}

resource "aws_apigatewayv2_route" "my_route" {
  api_id    = aws_apigatewayv2_api.my_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.my_api.id
  name        = "default"
  auto_deploy = true
}

output "api_endpoint" {
  # value = aws_api_gateway_deployment.api_deployment.invoke_url
  value = aws_apigatewayv2_stage.default_stage.invoke_url
}

# API Gateway REST API
# resource "aws_api_gateway_rest_api" "my_api" {
#   name = "MyRestApi"
# }

# # API Gateway Resource
# resource "aws_api_gateway_resource" "api_resource" {
#   rest_api_id = aws_api_gateway_rest_api.my_api.id
#   parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
#   path_part   = "my-resource" # The path for this resource (e.g., /my-resource)
# }

# # API Gateway Method
# resource "aws_api_gateway_method" "http_method" {
#   rest_api_id   = aws_api_gateway_rest_api.my_api.id
#   resource_id   = aws_api_gateway_resource.api_resource.id
#   http_method   = "ANY"
#   authorization = "NONE"
# }

# # VPC Link
# resource "aws_api_gateway_vpc_link" "vpc_link" {
#   name = "MyVpcLink"

#   target_arns = [aws_lb.my_alb.arn] # Private ALB ARN
# }

# # API Gateway Integration
# resource "aws_api_gateway_integration" "alb_integration" {
#   rest_api_id             = aws_api_gateway_rest_api.my_api.id
#   resource_id             = aws_api_gateway_resource.api_resource.id
#   http_method             = aws_api_gateway_method.http_method.http_method
#   integration_http_method = "ANY"
#   type                    = "HTTP"
#   uri                     = aws_lb.my_alb.dns_name
#   connection_type         = "VPC_LINK"
#   connection_id           = aws_api_gateway_vpc_link.vpc_link.id
# }

# # API Gateway Deployment
# resource "aws_api_gateway_deployment" "api_deployment" {
#   rest_api_id = aws_api_gateway_rest_api.my_api.id
  
#   depends_on = [aws_api_gateway_integration.alb_integration]
# }

# resource "aws_api_gateway_stage" "api_stage" {
#   deployment_id = aws_api_gateway_deployment.api_deployment.id
#   rest_api_id   = aws_api_gateway_rest_api.my_api.id
#   stage_name    = "default"
# }

# output "api_endpoint" {
#   # value = aws_api_gateway_deployment.api_deployment.invoke_url
#   value = aws_api_gateway_stage.api_stage.invoke_url
# }