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

# Create a new SSM document to wait for user data to finish
resource "aws_ssm_document" "cloud_init_wait" {
  name            = "${var.prefix}-cloud-init-wait"
  document_type   = "Command"
  document_format = "YAML"
  content         = file("scripts/cloud-init.yaml")
}

# Create an IAM role so that EC2 can talk to ssm
data "aws_iam_policy_document" "ssm_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_role" {
  name               = "${var.prefix}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_role_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.prefix}-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# Launch an EC2 instance to build an ami
resource "aws_instance" "ami_builder" {
  ami                    = "ami-06bd7f67e90613d1a" # debian
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.security_group.id]
  user_data = templatefile("scripts/user-data.sh",
    {
      noip_username  = var.noip_username
      noip_password  = var.noip_password
      noip_domain    = var.noip_domain
      openvpn_script = var.openvpn_script
    }
  )
  user_data_replace_on_change = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
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
resource "null_resource" "ami_builder_provisioner" {
  triggers = {
    instance_id = aws_instance.ami_builder.id
  }
  provisioner "local-exec" {
    command = templatefile(
      "scripts/cloud-init-wait.sh",
      {
        aws_region       = data.aws_region.current.name
        ssm_document_arn = aws_ssm_document.cloud_init_wait.arn
        instance_id      = aws_instance.ami_builder.id
      }
    )
    interpreter = ["bash", "-c"]
  }
}

# Create an AMI from the EC2 instance
resource "aws_ami_from_instance" "vpn_ami" {
  source_instance_id = aws_instance.ami_builder.id
  name               = "${var.prefix}-vpn-ami"
  depends_on         = [null_resource.ami_builder_provisioner]
  tags = {
    Name = "${var.prefix}-vpn-ami"
  }
}

# Stop the ami builder EC2 instance
resource "aws_ec2_instance_state" "ami_builder_stop" {
  instance_id = aws_instance.ami_builder.id
  state       = "stopped"
  depends_on  = [aws_ami_from_instance.vpn_ami]
}

# Create a launch template for the VPN instances
resource "aws_launch_template" "vpn" {
  name_prefix            = "${var.prefix}-vpn-template-"
  image_id               = aws_ami_from_instance.vpn_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.security_group.id]
}

# Create an Auto Scaling Group for VPN instances
resource "aws_autoscaling_group" "vpn_asg" {
  name = "${var.prefix}-vpn-asg"
  launch_template {
    id      = aws_launch_template.vpn.id
    version = "$Latest"
  }
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.public.id]
  health_check_type   = "EC2"

  tag {
    key                 = "Name"
    value               = "${var.prefix}-vpn-ec2"
    propagate_at_launch = true
  }
}

# auto scaling
resource "aws_autoscaling_schedule" "scale_in_evening" {
  scheduled_action_name  = "${var.prefix}-scale-in-evening"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  autoscaling_group_name = aws_autoscaling_group.vpn_asg.name
  recurrence             = "00 19 * * *"
  time_zone              = "Europe/London"
}

resource "aws_autoscaling_schedule" "scale_out_month_end_morning" {
  scheduled_action_name  = "${var.prefix}-scale-out-month-end-morning"
  min_size               = 1
  max_size               = 1
  desired_capacity       = 1
  autoscaling_group_name = aws_autoscaling_group.vpn_asg.name
  recurrence             = "00 02 L * ? *"
  time_zone              = "Europe/London"
}

resource "aws_autoscaling_schedule" "scale_in_month_end_morning" {
  scheduled_action_name  = "${var.prefix}-scale-in-month-end-morning"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  autoscaling_group_name = aws_autoscaling_group.vpn_asg.name
  recurrence             = "05 02 L * ? *"
  time_zone              = "Europe/London"
}
