data "aws_region" "current" {}

# Create a new VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.prefix}-vpn-vpc"
  }
}

# Create a new public subnet within the VPC
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.prefix}-vpn-public-subnet"
  }
}

# Create a new Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.prefix}-vpn-igw"
  }
}

# Create a new route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.prefix}-public-route-table"
  }
}

# Create a new route to the Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a new security group
resource "aws_security_group" "security_group" {
  vpc_id = aws_vpc.vpc.id
  name   = "${var.prefix}-vpn-sg"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access"
  }
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow VPN access"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.prefix}-vpn-sg"
  }
}

# Create a new SSH key pair
resource "aws_key_pair" "key_pair" {
  key_name   = "${var.prefix}-vpn-key-pair"
  public_key = var.public_key
}

data "template_file" "user_data" {
  template = file("scripts/user-data.sh")
  vars = {
    noip_username  = var.noip_username
    noip_password  = var.noip_password
    noip_domain    = var.noip_domain
    openvpn_script = var.openvpn_script
  }
}

# Create a new SSM document to wait for user data to finish
resource "aws_ssm_document" "cloud_init_wait" {
  name            = "${var.prefix}-cloud-init-wait"
  document_type   = "Command"
  document_format = "YAML"
  content         = file("scripts/cloud-init.yaml")
}

# Launch an EC2 instance to build an ami
resource "aws_instance" "ami_builder" {
  ami                         = "ami-06bd7f67e90613d1a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  key_name                    = aws_key_pair.key_pair.key_name
  security_groups             = [aws_security_group.security_group.id]
  user_data                   = data.template_file.user_data.rendered
  user_data_replace_on_change = true
  tags = {
    Name = "${var.prefix}-vpn-ec2-builder"
  }
  lifecycle {
    replace_triggered_by = [
      aws_vpc.vpc,
      aws_subnet.public,
      aws_security_group.security_group,
      aws_route.public_internet_gateway,
      aws_route_table_association.public,
      aws_key_pair.key_pair,
      aws_internet_gateway.igw,
      aws_route_table.public
    ]
  }
}

# Create a script to wait for the services to start
data "template_file" "provisioner_script" {
  template = file("scripts/cloud-init-wait.sh")

  vars = {
    aws_region       = data.aws_region.current.name
    ssm_document_arn = aws_ssm_document.cloud_init_wait.arn
    instance_id      = aws_instance.ami_builder.id
  }
}

resource "null_resource" "ami_builder_provisioner" {
  triggers = {
    instance_id = aws_instance.ami_builder.id
  }
  provisioner "local-exec" {
    command = "bash -c '${data.template_file.provisioner_script.rendered}'"
  }
  depends_on = [aws_instance.ami_builder]
}

# Create an AMI from the EC2 instance
resource "aws_ami_from_instance" "vpn_ami" {
  source_instance_id = aws_instance.ami_builder.id
  name               = "${var.prefix}-vpn-ami"
  depends_on         = [null_resource.ami_builder_provisioner]
}

# Stop the EC2 instance
resource "aws_ec2_instance_state" "ami_builder_stop" {
  instance_id = aws_instance.ami_builder.id
  state       = "stopped"
  depends_on  = [aws_ami_from_instance.vpn_ami]
}

# Use the created AMI to launch a new EC2 instance
resource "aws_instance" "vpn" {
  ami             = aws_ami_from_instance.vpn_ami.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public.id
  key_name        = aws_key_pair.key_pair.key_name
  security_groups = [aws_security_group.security_group.id]
  tags = {
    Name = "${var.prefix}-vpn-ec2"
  }
}

# Ensure the server is running on terraform deploy
resource "aws_ec2_instance_state" "vpn_running" {
  instance_id = aws_instance.vpn.id
  state       = "running"
}
