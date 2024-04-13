# Create a new VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.prefix}-vpn-vpc"
  }
}

# Create a new public subnet within the VPC
resource "aws_subnet" "subnet" {
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
  template = file("scripts/user-data.tpl")
  vars = {
    noip_username  = var.noip_username
    noip_password  = var.noip_password
    noip_domain    = var.noip_domain
    openvpn_script = var.openvpn_script
  }
}

# Launch an EC2 instance
resource "aws_instance" "instance" {
  ami             = "ami-004961349a19d7a8f"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.subnet.id
  key_name        = aws_key_pair.key_pair.key_name
  security_groups = [aws_security_group.security_group.name]
  user_data       = data.template_file.user_data.rendered
  tags = {
    Name = "${var.prefix}-vpn-ec2"
  }
}
