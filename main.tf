provider "aws" {
  region = "eu-central-1a"
}

resource "aws_vpc" "Swarm_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    "Name" = "Swarm_vpc"
  }
}

// Provision a private subnet in the VPC

resource "aws_subnet" "Swarm_private-subnet" {
  availability_zone = "eu-central-1a"
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.Swarm_vpc.id
  tags = {
    "Name" = "Swarm_private-subnet"
  }
}

resource "tls_private_key" "Swarm_tls-private-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "Swarm_key-pair" {
  key_name = "Swarm_key-pair"
  public_key = tls_private_key.Swarm_tls-private-key.public_key_openssh
}

output "ssh_private_key_pem" {
  value = tls_private_key.Swarm_tls-private-key.private_key_pem
  sensitive = true
}

output "ssh_public_key_pem" {
  value = tls_private_key.Swarm_tls-private-key.public_key_pem
}

resource "aws_security_group" "Swarm_private-securitygroup" {
  name = "Swarm_private-securitygroup"
  description = "Swarm_private-securitygroup"
  vpc_id = aws_vpc.Swarm_vpc.id
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
    "Name" = "Swarm_private-securitygroup"
  }
}

// Provision EC2 instances in the private subnet

resource "aws_instance" "Swarm_master" {
  count = 2
  instance_type = "t2.micro"
  ami = "ami-03c7d01cf4dedc891"
  subnet_id = aws_subnet.Swarm_private-subnet.id
  security_groups = [aws_security_group.Swarm_private-securitygroup.id]
  key_name = aws_key_pair.Swarm_key-pair.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "master-${count.index + 1}"
  }
}

resource "aws_instance" "Swarm_worker" {
  count = 3
  instance_type = "t2.micro"
  ami = "ami-03c7d01cf4dedc891"
  subnet_id = aws_subnet.Swarm_private-subnet.id
  security_groups = [aws_security_group.Swarm_private-securitygroup.id]
  key_name = aws_key_pair.Swarm_key-pair.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "worker-${count.index + 1}"
  }
}

resource "aws_instance" "Swarm_ansible" {
  instance_type = "t2.micro"
  ami = "ami-03c7d01cf4dedc891"
  subnet_id = aws_subnet.Swarm_private-subnet.id
  security_groups = [aws_security_group.Swarm_private-securitygroup.id]
  key_name = aws_key_pair.Swarm_key-pair.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "ansible"
  }
}

// Provision a public subnet in the VPC

resource "aws_subnet" "Swarm_public-subnet" {
  availability_zone = "eu-central-1a"
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.Swarm_vpc.id
  tags = {
    "Name" = "Swarm_public-subnet"
  }
}

// Provision an internet gateway in the public subnet

resource "aws_internet_gateway" "Swarm_internet-gateway" {
  vpc_id = aws_vpc.Swarm_vpc.id
  tags = {
    "Name" = "Swarm_internet-gateway"
  }
}

resource "aws_route_table" "Swarm_internet-gateway-route-table" {
  vpc_id = aws_vpc.Swarm_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Swarm_internet-gateway.id
  }
}

resource "aws_route_table_association" "Swarm_internet-gateway-route-table-association" {
  subnet_id = aws_subnet.Swarm_public-subnet.id
  route_table_id = aws_route_table.Swarm_internet-gateway-route-table.id
}

// Provision a NAT gateway in the public subnet

resource "aws_eip" "Swarm_eip" {
  vpc = true
}

resource "aws_nat_gateway" "Swarm_nat-gateway" {
  allocation_id = aws_eip.Swarm_eip.id
  subnet_id = aws_subnet.Swarm_public-subnet.id
  tags = {
    "Name" = "Swarm_nat-gateway"
  }
}

output "nat_gateway_ip" {
  value = aws_eip.Swarm_eip.public_ip
}

resource "aws_route_table" "Swarm_NAT-gateway-route-table" {
  vpc_id = aws_vpc.Swarm_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.Swarm_nat-gateway.id
  }
}

resource "aws_route_table_association" "instance" {
  subnet_id = aws_subnet.Swarm_public-subnet.id
  route_table_id = aws_route_table.Swarm_NAT-gateway-route-table.id
}

// Provision EC2 instances in the private subnet

resource "aws_instance" "Swarm_ec2jumphost" {
  instance_type = "t2.micro"
  ami = "ami-03c7d01cf4dedc891"
  subnet_id = aws_subnet.Swarm_public-subnet.id
  security_groups = [aws_security_group.Swarm_private-securitygroup.id]
  key_name = aws_key_pair.Swarm_key-pair.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "Swarm_ec2jumphost"
  }
}

resource "aws_eip" "Swarm_jumphost" {
  instance = aws_instance.Swarm_ec2jumphost.id
  vpc = true
}

output "jumphost_ip" {
  value = aws_eip.Swarm_jumphost.public_ip
}
