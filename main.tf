provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    "Name" = "Swarm_VPC"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "instance" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "Swarm_SubnetInstance"
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name = "JumphostMachine"
  public_key = tls_private_key.ssh.public_key_openssh
}

output "ssh_private_key_pem" {
  sensitive = true
  value = tls_private_key.ssh.private_key_pem
}

output "ssh_public_key_pem" {
  value = tls_private_key.ssh.public_key_pem
}

resource "aws_security_group" "securitygroup" {
  name = "SwarmSecurityGroup"
  description = "SwarmSecurityGroup"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 2377
    to_port = 2377
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 7946
    to_port = 7946
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 4789
    to_port = 4789
    protocol = "udp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
  tags = {
    "Name" = "SwarmSecurityGroup"
  }
}

resource "aws_instance" "Cluster_master" {
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
  user_data = <<-EOF
    #! /bin/bash
    # Copy private key
    echo "${tls_private_key.ssh.private_key_pem}" > /home/ubuntu/.ssh/id_rsa
    sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
    sudo chmod 600 /home/ubuntu/.ssh/id_rsa
    # Install docker
    sudo apt-get update
    sudo apt-get install docker.io -y
    # Initialize swarm cluster
    sudo docker swarm init --advertise-addr $(ip a show eth0 | grep 'inet ' | awk {'print $2'} | cut -d/ -f1)
    # Change hostname
    sudo sed -i "s/$HOSTNAME/Cluster_master/g" /etc/hosts
    sudo sed -i "s/$HOSTNAME/Cluster_master/g" /etc/hostname
    sudo hostname Cluster-master
  EOF
  tags = {
    Name = "Cluster_master"
  }
}

output "Cluster_master_ips" {
  description = "The private IP addresses of the swarm masters"
  value       = aws_instance.Cluster_master.private_ip
}

resource "aws_instance" "master" {
  count = 1
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
  depends_on = [
    aws_instance.Cluster_master
  ]
  user_data = <<-EOF
    #! /bin/bash
    # Copy private key
    echo "${tls_private_key.ssh.private_key_pem}" > /home/ubuntu/.ssh/id_rsa
    sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
    sudo chmod 600 /home/ubuntu/.ssh/id_rsa
    # Install docker
    sudo apt-get update
    sudo apt-get install docker.io -y
    # Join swarm cluster as manager
    token=$(su -c 'ssh -o StrictHostKeyChecking=no ubuntu@${aws_instance.Cluster_master.private_ip} "sudo docker swarm join-token manager"' ubuntu)
    join=$(echo $join | awk -F "command: " '{print $2}')
    $join
    # Change hostname
    sudo sed -i "s/$HOSTNAME/master-${count.index + 1}/g" /etc/hosts
    sudo sed -i "s/$HOSTNAME/master-${count.index + 1}/g" /etc/hostname
    sudo hostname master-${count.index + 1}
  EOF
  tags = {
    Name = "master-${count.index + 1}"
  }
}

output "master_ips" {
  description = "The private IP addresses of the swarm masters"
  value       = aws_instance.master.*.private_ip
}

resource "aws_instance" "worker" {
  count = 3
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
  depends_on = [
    aws_instance.Cluster_master
  ]
  user_data = <<-EOF
    #! /bin/bash
    # Copy private key
    echo "${tls_private_key.ssh.private_key_pem}" > /home/ubuntu/.ssh/id_rsa
    sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
    sudo chmod 600 /home/ubuntu/.ssh/id_rsa
    # Install docker
    sudo apt-get update
    sudo apt-get install docker.io -y
    # Join swarm cluster as worker
    token=$(su -c 'ssh -o StrictHostKeyChecking=no ubuntu@${aws_instance.Cluster_master.private_ip} "sudo docker swarm join-token worker"' ubuntu)
    join=$(echo $join | awk -F "command: " '{print $2}')
    $join
    # Change hostname
    sudo sed -i "s/$HOSTNAME/worker-${count.index + 1}/g" /etc/hosts
    sudo sed -i "s/$HOSTNAME/worker-${count.index + 1}/g" /etc/hostname
    sudo hostname worker-${count.index + 1}
  EOF
  tags = {
    Name = "worker-${count.index + 1}"
  }
}

output "worker_ips" {
  description = "The private IP addresses of the swarm workers"
  value       = aws_instance.worker.*.private_ip
}

resource "aws_instance" "ansible" {
  count = 1
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
  user_data = <<-EOF
    #! /bin/bash
    # Copy private key
    echo "${tls_private_key.ssh.private_key_pem}" > /home/ubuntu/.ssh/id_rsa
    sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
    sudo chmod 600 /home/ubuntu/.ssh/id_rsa
    # Install ansible
    sudo apt-get update
    sudo apt-add-repository ppa:ansible/ansible -y
    sudo apt-get update
    sudo apt-get install ansible -y
    # Change hostname
    sudo sed -i "s/$HOSTNAME/ansible-${count.index + 1}/g" /etc/hosts
    sudo sed -i "s/$HOSTNAME/ansible-${count.index + 1}/g" /etc/hostname
    sudo hostname ansible-${count.index + 1}
  EOF
  tags = {
    Name = "ansible-${count.index + 1}"
  }
}

output "ansible_ips" {
  description = "The private IP addresses of the ansible instances"
  value       = aws_instance.ansible.*.private_ip
}

resource "aws_subnet" "nat_gateway" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "SwarmSubnetNAT"
  }
}

resource "aws_internet_gateway" "nat_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "SwarmGateway"
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
    "Name" = "SwarmNatGateway"
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
  user_data = <<-EOF
    #! /bin/bash
    # Copy private key
    echo "${tls_private_key.ssh.private_key_pem}" > /home/ubuntu/.ssh/id_rsa
    sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
    sudo chmod 600 /home/ubuntu/.ssh/id_rsa
    # Change hostname
    sudo sed -i "s/$HOSTNAME/jumphost/g" /etc/hosts
    sudo sed -i "s/$HOSTNAME/jumphost/g" /etc/hostname
    sudo hostname jumphost
  EOF
  tags = {
    "Name" = "SwarmMachineJumphost"
  }
}

resource "aws_eip" "jumphost" {
  instance = aws_instance.ec2jumphost.id
  vpc = true
}

output "jumphost_ip" {
  description = "The public IP addresse of the jumphost"
  value = aws_eip.jumphost.public_ip
}
