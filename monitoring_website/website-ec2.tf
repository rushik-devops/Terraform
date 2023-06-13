#Defining provider
provider "aws" {
        shared_credentials_files = ["/root/.aws/credentials"]
	region = "us-east-1"
}


#Defining common tags for security group and ec2 instance
locals {
	common_tags = {
		Name = "website"
	}
}


#Create SG and allow prots 80 for nginx website, 22 for ssh and 443 for updating the instance
resource "aws_security_group" "allowhttp" {
	name = "website_http"
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
	ingress {
		from_port = 5000
		to_port   = 5000
		protocol  = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	egress {
		from_port = 443
		to_port   = 443
		protocol  = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = local.common_tags
}


#Creating key-pair value to assign to ec2 instance
resource "tls_private_key" "webkey" {
	algorithm = "RSA"
}

resource "local_file" "nginxkey" {
	content = tls_private_key.webkey.private_key_pem
	filename = "nginxkey.pem"
}

resource "aws_key_pair" "website" {
	key_name = "nginxkey"
	public_key = tls_private_key.webkey.public_key_openssh
}


#Creating ec2 instance
resource "aws_instance" "website" {
	ami = "ami-02396cdd13e9a1257"
	instance_type = "t2.micro"
	key_name = aws_key_pair.website.key_name
	tags = local.common_tags
#Assigning SG to ec2 instance
	vpc_security_group_ids = [aws_security_group.allowhttp.id]

#Connecting to ec2 instance with above created private key
	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = tls_private_key.webkey.private_key_pem
		host = self.public_ip
	}

#Executing the required commands in remote host ie ec2 isntance
	provisioner "remote-exec" {
		inline = [
			"sudo yum install nginx* -y",
			"sudo systemctl start nginx",
			"sudo mkdir -p /usr/share/nginx/html/python/templates",
			"sudo chmod 777 /usr/share/nginx/html/python/templates",
			"sudo chmod 777 /usr/share/nginx/html/python",
			"sudo chmod 777 /usr/share/nginx/html/index.html"
		]
	}

#Copying files from local machine to remote host
        provisioner "file" {
		source = "monitor.py"
		destination = "/usr/share/nginx/html//python/monitor.py"
	}
	provisioner "file" {
		source = "index.html"
		destination = "/usr/share/nginx/html/index.html"
	}
        provisioner "file" {
                source = "templates/index.html"
                destination = "/usr/share/nginx/html/python/templates/index.html"
	}
	
	provisioner "file" {
		source = "requirements.txt"
		destination = "/tmp/requirements.txt"
	}

	provisioner "remote-exec" {
		inline = [
			"sudo yum install python3-pip -y",
			"sudo pip3 install -r /tmp/requirements.txt",
			"sudo python3 /usr/share/nginx/html/python/monitor.py"
		]
	}

}
