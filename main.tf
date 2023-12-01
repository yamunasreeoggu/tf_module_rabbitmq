 resource "aws_security_group" "main" {
  name        = "${var.env}-${var.component}-sg"
  description = "${var.env}-${var.component}-sg"
  vpc_id      = var.vpc_id

  ingress {
    description      = "RABBITMQ"
    from_port        = 5672
    to_port          = 5672
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-${var.component}-sg"
  }
}

 resource "aws_iam_role" "role" {
   name = "${var.env}-${var.component}-role"

   assume_role_policy = jsonencode({
     Version = "2012-10-17"
     Statement = [
       {
         Action = "sts:AssumeRole"
         Effect = "Allow"
         Sid    = ""
         Principal = {
           Service = "ec2.amazonaws.com"
         }
       },
     ]
   })

   inline_policy {
     name = "${var.env}-${var.component}-policy"

     policy = jsonencode({
       "Version": "2012-10-17",
       "Statement": [
         {
           "Sid": "VisualEditor0",
           "Effect": "Allow",
           "Action": [
             "kms:Decrypt",
             "ssm:DescribeParameters",
             "ssm:GetParameterHistory",
             "ssm:GetParametersByPath",
             "ssm:GetParameters",
             "ssm:GetParameter"
           ],
           "Resource": "*"
         }
       ]
     })
   }

   tags = {
     tag-key = "${var.env}-${var.component}-role"
   }
 }

 resource "aws_iam_instance_profile" "instance_profile" {
   name = "${var.env}-${var.component}-role"
   role = aws_iam_role.role.name
 }

 resource "aws_instance" "main" {
   ami = data.aws_ami.ami.id
   instance_type = var.rabbitmq_instance_type
   vpc_security_group_ids = [aws_security_group.main.id]
   subnet_id = var.subnets[0]
   iam_instance_profile = aws_iam_instance_profile.instance_profile.name

   user_data   = base64encode(templatefile("${path.module}/userdata.sh", {
     role_name = var.component,
     env       = var.env
   }))

   tags = {
     Name = "${var.env}-${var.component}"
   }

   root_block_device {
     encrypted = true
     kms_key_id = var.kms_key_id
   }
 }

 resource "aws_route53_record" "record" {
   zone_id = var.zone_id
   name    = "${var.component}-${var.env}"
   type    = "A"
   ttl     = 30
   records = [aws_instance.main.private_ip]
 }