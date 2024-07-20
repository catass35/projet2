provider "aws" {
  region = "us-east-1"
}

// Create VPC
resource "aws_vpc" "Swarm_VPC" {
  cidr_block = "10.10.0.0/16"
}

// Create Subnet
resource "aws_subnet" "Swarm_Publicsubnet" {
  vpc_id     = aws_vpc.Swarm_VPC.id
  cidr_block = "10.10.1.0/24"

  tags = {
    Name = "Swarm_Publicsubnet"
  }
}

// Create Internet Gateway
resource "aws_internet_gateway" "Swarm_gw" {
  vpc_id = aws_vpc.Swarm_VPC.id

  tags = {
    Name = "Swarm_gw"
  }
}

// Create Route Table
resource "aws_route_table" "Swarm_routetable" {
  vpc_id = aws_vpc.Swarm_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Swarm_gw.id
  }

  tags = {
    Name = "Swarm_routetable"
  }
}

//associate subnet with route table
resource "aws_route_table_association" "Swarm-rta" {
  subnet_id      = aws_subnet.Swarm_Publicsubnet.id
  route_table_id = aws_route_table.Swarm_routetable.id
}

// Create Security Group
resource "aws_security_group" "Swarm_SG" {
  name        = "Swarm_SG"
  vpc_id      = aws_vpc.Swarm_VPC.id

  ingress {
    from_port        = 20
    to_port          = 20
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Swarm_SG"
  }
}

// Create EC2 Instance
resource "aws_instance" "Swarm_master" {
  count         = 2
  ami           = "ami-03c7d01cf4dedc891" # us-east-1
  instance_type = "t2.micro"
  key_name   = "AmazonKEY"
  subnet_id = aws_subnet.Swarm_Publicsubnet.id
  vpc_security_group_ids = [aws_security_group.Swarm_SG.id]

  tags = {
    Name = "master-${count.index + 1}"
  }
}

// Create EC2 Instance
resource "aws_instance" "Swarm_worker" {
  count         = 3
  ami           = "ami-03c7d01cf4dedc891" # us-east-1
  instance_type = "t2.micro"
  key_name   = "AmazonKEY"
  subnet_id = aws_subnet.Swarm_Publicsubnet.id
  vpc_security_group_ids = [aws_security_group.Swarm_SG.id]

  tags = {
    Name = "worker-${count.index + 1}"
  }
}

