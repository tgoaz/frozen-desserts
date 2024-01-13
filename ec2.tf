provider "aws" {
  profile = "default"
  region = "us-east-1"
  shared_credentials_files = ["$HOME/.aws/credentials"]
  #version = "5.30.0"
}

resource "aws_security_group" "dessert-sec" {
  name        = "allow-ssh-and-port-3000"
  description = "Allow incoming and outgoing traffic on port 22 (SSH) and port 3000"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "desserts" {
  ami           = "ami-0c7217cdde317cfec"  # Replace with the desired Ubuntu AMI ID
  instance_type = "t2.micro"
  key_name      = "dessert"      # Replace with your EC2 key pair name

  vpc_security_group_ids = [aws_security_group.dessert-sec.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y php curl g++ gcc autoconf automake bison libc6-dev libffi-dev libgdbm-dev libncurses5-dev libsqlite3-dev libtool libyaml-dev make pkg-config sqlite3 zlib1g-dev libgmp-dev libreadline-dev libssl-dev
              export HOME=/home/ubuntu/
              curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
              curl -sSL https://get.rvm.io | bash -s stable
              source /etc/profile.d/rvm.sh
              rvm install ruby-3.2.1
              git clone https://github.com/StrongMind/frozen-desserts.git /home/ubuntu/frozen-desserts/
              sudo chown 777 /home/ubuntu/frozen-desserts/
              cd /home/ubuntu/frozen-desserts && bundle install
              cd /home/ubuntu/frozen-desserts && rails s -b 0.0.0.0
              EOF
}

