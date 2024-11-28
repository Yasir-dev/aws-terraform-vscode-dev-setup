# create VPC
resource "aws_vpc" "dev_setup_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev-setup-vpc"
  }
}

# create Subnet
resource "aws_subnet" "dev_setup_public_subnet" {
  vpc_id                  = aws_vpc.dev_setup_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "dev-setup-public-subnet"
  }
}

# create Internet Gateway
resource "aws_internet_gateway" "dev-setup-igw" {
  vpc_id = aws_vpc.dev_setup_vpc.id

  tags = {
    Name = "dev-setup-igw"
  }
}

# create route table
resource "aws_route_table" "dev_setpup_public_rt" {
  vpc_id = aws_vpc.dev_setup_vpc.id

  tags = {
    Name = "dev_setpup_public_rt"
  }
}

# create route
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.dev_setpup_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dev-setup-igw.id
}

# associate route table to subnet
resource "aws_route_table_association" "dev_setup_public_subnet_association" {
  subnet_id      = aws_subnet.dev_setup_public_subnet.id
  route_table_id = aws_route_table.dev_setpup_public_rt.id
}

# add security groups
resource "aws_security_group" "dev_setup_security_group" {
  name        = "dev_setup_sg"
  description = "Dev Security Group"
  vpc_id      = aws_vpc.dev_setup_vpc.id

  tags = {
    Name = "dev_setup_sg"
  }
}

# inbound traffic
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_anywhere" {
  security_group_id = aws_security_group.dev_setup_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22

  tags = {
    Name = "Allow SSH from anywhere"
  }
}

# outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_for_outbound" {
  security_group_id = aws_security_group.dev_setup_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  ip_protocol       = "-1"
  to_port           = 0

  tags = {
    Name = "Allow all internet access from outbound"
  }
}

# add key paint resource
resource "aws_key_pair" "dev_auth" {
  key_name   = "dev-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

# add ec2 instance
resource "aws_instance" "dev_instance" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.dev_auth.id
  vpc_security_group_ids = [aws_security_group.dev_setup_security_group.id]
  subnet_id              = aws_subnet.dev_setup_public_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-intance"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/id_ed25519"
    })
    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-Command"]
  }
}
