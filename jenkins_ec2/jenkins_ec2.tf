#Defining provider
provider "aws" {
        shared_credentials_files = ["/root/.aws/credentials"]
	region = "us-east-1"
}


#Defining common tags for security group and ec2 instance
locals {
	common_tags = {
		Name = "jenkins_server"
	}
}


#Create SG and allow prots 80 for hosting jenkins, 22 for ssh and 443 for updating the instance
resource "aws_security_group" "jenkins" {
	name = "jenkins"
	vpc_id = "vpc-055e4421a8373c39e"
	ingress {
		from_port = 80
		to_port   = 80
		protocol  = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
		from_port = 22
		to_port   = 22
		protocol  = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	egress {
		from_port = 0
		to_port   = 65535
		protocol  = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
		from_port = 8080
		to_port   = 8080
		protocol  = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = local.common_tags
}


#Creating key-pair value to assign to ec2 instance
resource "tls_private_key" "jenkinskey" {
	algorithm = "RSA"
}

resource "local_file" "jenkins" {
	content = tls_private_key.jenkinskey.private_key_pem
	filename = "jenkins.pem"
}

resource "aws_key_pair" "jenkinshost" {
	key_name = "jenkins"
	public_key = tls_private_key.jenkinskey.public_key_openssh
}


#Creating ec2 instance
resource "aws_instance" "jenkins" {
	ami = "ami-022e1a32d3f742bd8"
	instance_type = "t2.micro"
	key_name = aws_key_pair.jenkinshost.key_name
	tags = local.common_tags
#Assigning SG to ec2 instance
	vpc_security_group_ids = [aws_security_group.jenkins.id]

#Connecting to ec2 instance with above created private key
	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = tls_private_key.jenkinskey.private_key_pem
		host = self.public_ip
	}

#Executing the required commands in remote host ie ec2 isntance
	provisioner "remote-exec" {
		inline = [
			"sudo yum update –y",
			"sudo wget -o /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
			"sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",
			"sudo dnf install java-11-amazon-corretto -y",
			"sudo yum install jenkins -y",
			"sudo systemctl enable jenkins",
			"sudo systemctl start jenkins",
		]
	}


}
