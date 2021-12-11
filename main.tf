terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  cloud {
    organization = "abrantes"

    workspaces {
      name = "ezops_iac"
    }
  }
}

provider "aws" {
  region     = "us-east-2"
}

variable "public_key" {
  type        = string
}

resource "tls_private_key" "test_tls" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "test_key" {
  key_name   = "test-key"
  public_key = tls_private_key.test_tls.public_key_openssh

  provisioner "local-exec" { 
    command = "echo '${tls_private_key.test_tls.private_key_pem}' > ./test-key.pem"
  }
}

resource "aws_security_group" "test_sg" {
  name = "test-sg"
  ingress {
    from_port   = 22 
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80 
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "test_instance" {
  ami           = "ami-0629230e074c580f2"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.test_key.key_name
  vpc_security_group_ids  = [aws_security_group.test_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              curl -fsSL https://get.docker.com -o get-docker.sh 
              sudo sh get-docker.sh 
              sudo apt-get install nginx -y 
              echo ${var.public_key} > /root/.ssh/authorized_keys
              EOF
  tags = {
    Name = "test-instance"
  }
}

output "public_ip" {
  value = aws_instance.test_instance.public_dns
}
