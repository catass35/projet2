provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    "Name" = "Dummy"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "instance" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "DummySubnetInstance"
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name = "DummyMachine"
  public_key = tls_private_key.ssh.public_key_openssh
}

output "ssh_private_key_pem" {
  value = tls_private_key.ssh.private_key_pem
}

output "ssh_public_key_pem" {
  value = tls_private_key.ssh.public_key_pem
}

resource "aws_security_group" "securitygroup" {
  name = "DummySecurityGroup"
  description = "DummySecurityGroup"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
  tags = {
    "Name" = "DummySecurityGroup"
  }
}

resource "aws_instance" "ec2instance" {
  instance_type = "t2.micro"
  ami = "ami-03d8059563982d7b0" # https://cloud-images.ubuntu.com/locator/ec2/ (Ubuntu)
  subnet_id = aws_subnet.instance.id
  security_groups = [aws_security_group.securitygroup.id]
  key_name = aws_key_pair.ssh.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "DummyMachine"
  }
}

output "instance_private_ip" {
  value = aws_instance.ec2instance.private_ip
}

resource "aws_subnet" "nat_gateway" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "DummySubnetNAT"
  }
}

resource "aws_internet_gateway" "nat_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "DummyGateway"
  }
}

resource "aws_route_table" "nat_gateway" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "nat_gateway" {
  subnet_id = aws_subnet.nat_gateway.id
  route_table_id = aws_route_table.nat_gateway.id
}

resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id = aws_subnet.nat_gateway.id
  tags = {
    "Name" = "DummyNatGateway"
  }
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

resource "aws_route_table" "instance" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "instance" {
  subnet_id = aws_subnet.instance.id
  route_table_id = aws_route_table.instance.id
}

resource "aws_instance" "ec2jumphost" {
  instance_type = "t2.micro"
  ami = "ami-03d8059563982d7b0" # https://cloud-images.ubuntu.com/locator/ec2/ (Ubuntu)
  subnet_id = aws_subnet.nat_gateway.id
  security_groups = [aws_security_group.securitygroup.id]
  key_name = aws_key_pair.ssh.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "DummyMachineJumphost"
  }
}

resource "aws_eip" "jumphost" {
  instance = aws_instance.ec2jumphost.id
  vpc = true
}

output "jumphost_ip" {
  value = aws_eip.jumphost.public_ip
}
