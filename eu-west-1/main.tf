terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "access_key" {
  description = "Enter access key"

}

variable "secret_key" {
  description = "Enter secret key"
  
}

provider "aws"{
  region = "eu-west-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# Create Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "main"
  }
}

# Create Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# Create a Subnet
resource "aws_subnet" "subnet-2" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Security Groups
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_traffic"
  description = "Allow ssh traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "allow_ping" {
  name        = "allow_ping"
  description = "Allow ping from public internet"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "Allow ping"
    from_port        = 8
    to_port          = 0
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ping"
  }
}

# Create a Network Interface
resource "aws_network_interface" "ssh-server" {
  subnet_id       = aws_subnet.subnet-2.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_ssh.id, aws_security_group.allow_ping.id]
}

# Assign Elastic IP to Network Interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.ssh-server.id
  associate_with_private_ip = "10.0.1.50"
}

# Create Ubuntu Server
resource "aws_instance" "ssh-server-instance" {
  ami = "ami-0d75513e7706cf2d9"
  instance_type = "t2.micro"
  availability_zone = "eu-west-1a"
  # key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.ssh-server.id
  }
}