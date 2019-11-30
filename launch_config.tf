
resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"

  tags = {
    Name = "myvpc"
  }
}
## availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

## Creating a subnet01 in us-east-2a
resource "aws_subnet" "sub01" {
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  cidr_block        = "${var.sub1_cidr}"

  tags = {
    Name = "subnet01"
  }
}
## Creating a subnet02 in us-east-2b
resource "aws_subnet" "sub02" {
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  cidr_block        = "${var.sub2_cidr}"

  tags = {
    Name = "subnet02"
  }
}
## Creating an Internet Gateway and attched to VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "My_Internet_gateway"
  }
}
## Creating a Route Table
resource "aws_route_table" "route" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "${var.route_cidr}"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "My_Route_table"
  }
}
## Associating Route Table to subnet01
resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.sub01.id}"
  route_table_id = "${aws_route_table.route.id}"
}
## Associating Route Table to subnet02
resource "aws_route_table_association" "Ra" {
  subnet_id      = "${aws_subnet.sub02.id}"
  route_table_id = "${aws_route_table.route.id}"
}


resource "aws_security_group" "My_security" {
  name        = "My_security"
  description = "this SG for allowing all the ports"
  vpc_id      = "${aws_vpc.main.id}"

  ### Adding a new Inbound rules

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ### Adding a new outbound rule with All Traffic

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}




data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "setup" {
  template = "${file("${path.module}/Templates/first_page.sh")}"
}

resource "aws_key_pair" "My_key" {
  key_name   = "My_key"
  public_key = "${var.key_name}"
}


### creating launch configuration
resource "aws_launch_configuration" "as_conf" {
  name                        = "web_config"
  image_id                    = "${data.aws_ami.ubuntu.id}"
  instance_type               = "t2.micro"
  key_name                    = "${aws_key_pair.My_key.key_name}"
  security_groups             = ["${aws_security_group.My_security.id}"]
  associate_public_ip_address = "true"
  user_data                   = "${data.template_file.setup.rendered}"

}


### Create AutoScaling group 

resource "aws_autoscaling_group" "bar" {
  name                      = "terraform-asg-example"
  launch_configuration      = "${aws_launch_configuration.as_conf.name}"
  min_size                  = 1
  max_size                  = 2
  health_check_grace_period = 300
  desired_capacity          = 2
 vpc_zone_identifier       = ["${aws_subnet.sub01.id}", "${aws_subnet.sub02.id}"]

}



