terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  shared_credentials_file = "/home/nikhil/.aws/credentials"
}

# resource "aws_instance" "my-terra-instance" {
#   ami = "ami-0885b1f6bd170450c"
#   instance_type = "t2.micro"
#   tags = {
#     "Name" = "Terraform Instace"
#   }
# }

# resource "aws_vpc" "terraform-vpc" {
#   cidr_block       = "10.0.0.0/16"
#   instance_tenancy = "default"

#   tags = {
#     Name = "Terraform VPC"
#   }
# }


# resource "aws_subnet" "terraform-subnet" {
#   vpc_id     = aws_vpc.terraform-vpc.id
#   cidr_block = "10.0.1.0/24"

#   tags = {
#     Name = "Terraform Subnet"
#   }
# }

## Practice project

# 1. Create VPC
# 2. Create Internet gateway
# 3. Create custom route table
# 4. Create a subnet
# 5. Associate subnet with route table
# 6. Create security group and allow portds 22,80 ,443
# 7. Create a network interface witha an ip in the subnet that was created in step 4
# 8. Assign an elastic IP to the network interface created in step 7
# 9. Create Ubuntu server and install apache2


# 1. Create VPC
resource "aws_vpc" "terraform-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Terraform VPC"
  }
}

variable "ec2_name" {
  type = any
}

# 2. Create Internet gateway
resource "aws_internet_gateway" "terraform-gw" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = {
    Name = "Terraform Gateway"
  }
}

# 3. Create custom route table
resource "aws_route_table" "terraform-r" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.terraform-gw.id
  }

  tags = {
    Name = "Terraform Route table"
  }
}

# 4. Create a subnet
resource "aws_subnet" "terraform-subnet"{
  vpc_id = aws_vpc.terraform-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
}

# 5. Associate subnet with route table
resource "aws_route_table_association" "terraform_associate"{
  subnet_id  = aws_subnet.terraform-subnet.id
  route_table_id = aws_route_table.terraform-r.id
}

# 6. Create security group and allow portds 22,80 ,443
resource "aws_security_group" "allow_web" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Terrafrom SG"
  }
}

# 7. Create a network interface witha an ip in the subnet that was created in step 4
resource "aws_network_interface" "webserver-nic" {
  subnet_id       = aws_subnet.terraform-subnet.id
  private_ips     = ["10.0.0.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "terraform-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.webserver-nic.id
  associate_with_private_ip = "10.0.0.50"
  depends_on  = [aws_internet_gateway.terraform-gw, aws_instance.web-server-instance]
}

output "server_public_ip" {
  value = aws_eip.terraform-eip.public_ip
}

output "server_id" {
  value = "aws_instance.web-server-instance.id"
}

# 9. Create Ubuntu server and install apache2
resource "aws_instance" "web-server-instance"{
  ami = "ami-0885b1f6bd170450c"
  instance_type = "t2.micro"
  tags = {
    "Name" = var.ec2_name
  }
  availability_zone = "us-east-1a"
  key_name = "tf-key"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.webserver-nic.id
  }
  user_data = <<EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo "your very first web server redeployed" > /var/www/html/index.html'
                EOF
  
}