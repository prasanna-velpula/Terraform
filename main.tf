terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

#/*======AVAILABILITY ZONES=======*/
data "aws_availability_zones" "available" {
state = "available"
}

#/*=======PROVIDER=========*/
provider "aws" {
  region     = "us-east-2"
  access_key = "AKIAT26AKT5UAKFZCLEW"
  secret_key = "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"
}

#/*=====VPC======*/
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "My VPC"
  }
}

#/*=======SUBNETS=======*/
resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-2a"
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private-subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "us-east-2a"
  tags = {
    Name = "private-subnet"
  }
}

#/*======INTERNAL GATEWAY======*/
resource "aws_internet_gateway" "internet-gw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "internet-gw"
  }
}

#/*=======PUBLIC ROUTE TABLE & RTA========*/
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }
}

resource "aws_route_table_association" "public-rta" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}

#/*======ELASTICIP======*/
resource "aws_eip" "nat" {
  vpc = true
}

#/*======NAT=====*/
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-subnet.id
  depends_on    = [aws_internet_gateway.internet-gw]
}

#/*=======PRIVATE ROUTE TABLE & RTA======*/
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }
}

resource "aws_route_table_association" "private-rta" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private-rt.id
}

#/*====== SECURITY GROUPS=====*/
resource "aws_security_group" "allow-ssh" {
  vpc_id      = aws_vpc.my_vpc.id
  name        = "allow-ssh"
  description = "security group that allows ssh and all egress traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow-ssh"
  }
}
#/*=======INSTANCES======*/
resource "aws_instance" "public-instance" {
  ami         = "ami-077e31c4939f6a2f3"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.allow-ssh.id]
  key_name = "terraform"
  tags = {
    Name = "public-instance"
  }
}

resource "aws_instance" "private-instance" {
  ami           = "ami-077e31c4939f6a2f3" 
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private-subnet.id
  vpc_security_group_ids = [aws_security_group.allow-ssh.id]
  key_name = "terraform"
  tags = {
    Name = "private-instance"
  }
}
