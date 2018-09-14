locals {
  app_name     = "devops-playground"
  default_tags = {
    Name       = "${local.app_name}"
    App        = "${local.app_name}"
  }
}

/*
 * Create our VPC
 */
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 1.40.0"

  name = "${local.app_name}"
  cidr = "10.255.0.0/16"

  azs            = "${var.availability_zones}"
  public_subnets = ["10.255.1.0/24", "10.255.2.0/24", "10.255.3.0/24"]

  tags = "${local.default_tags}"
}

resource "aws_default_security_group" "vpc" {
  vpc_id = "${module.vpc.vpc_id}"

  # These are the defaults for the default security group. We have to specify 
  # them because we're overriding the default security group to add tags, so 
  # we can tell it apart from the other default security groups
  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(
    local.default_tags,
    map("Name", "${local.app_name}-default")
  )}"
}

/*
 * Create our security groups
 */
module "security_group_ssh" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 2.2.0"

  name        = "${local.app_name}-ssh"
  description = "Security group for web machines"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]

  ingress_rules = [
    "ssh-tcp",
  ]

  tags = "${merge(
    local.default_tags,
    map("Name", "${local.app_name}-ssh")
  )}"
}

module "security_group_web" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 2.2.0"

  name        = "${local.app_name}-web"
  description = "Security group for web machines"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]

  ingress_rules = [
    "http-80-tcp",
    "https-443-tcp"
  ]

  tags = "${merge(
    local.default_tags,
    map("Name", "${local.app_name}-web")
  )}"
}

/*
 * Create our autoscaling group
 */ 
data "aws_ami" "web" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.web_ami_name}"]
  }

  owners = ["self"]
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 2.8.0"

  name          = "${local.app_name}-web"

  image_id            = "${data.aws_ami.web.id}"
  instance_type       = "t2.nano"
  key_name            = "${var.ssh_key_name}"
  vpc_zone_identifier = "${module.vpc.public_subnets}"
  security_groups     = [
    "${module.vpc.default_security_group_id}",
    "${module.security_group_ssh.this_security_group_id}",
    "${module.security_group_web.this_security_group_id}",
  ]

  min_size          = 1
  max_size          = 1
  desired_capacity  = 1

  target_group_arns = ["${module.loadbalancer.target_group_arns}"]
  health_check_type = "ELB"
  min_elb_capacity  = 1

  recreate_asg_when_lc_changes = true

  tags_as_map = "${local.default_tags}"

  tags = [
    {
      key                 = "deployment_group"
      value               = "${local.app_name}"
      propogate_at_launch = true
    }
  ]
}

/*
 * Create the load balancer
 */
module "loadbalancer" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 3.4.0"

  load_balancer_name = "${local.app_name}"
  vpc_id             = "${module.vpc.vpc_id}"
  subnets            = ["${module.vpc.public_subnets}"]
  security_groups    = [
    "${module.vpc.default_security_group_id}",
    "${module.security_group_web.this_security_group_id}",
  ]

  logging_enabled = false

  http_tcp_listeners_count = 1
  http_tcp_listeners       = [
    {
      port               = 80
      protocol           = "HTTP"
    }
  ]

  target_groups_count = 1
  target_groups       = [
    {
      name                 = "${local.app_name}-default"
      backend_protocol     = "HTTP"
      backend_port         = 80
      deregistration_delay = 60
    }
  ]

  tags = "${local.default_tags}"
}

/*
 * Setup codedeploy 
 */
data "aws_iam_role" "codedeploy" {
  name = "sunfish-codedeploy"
}

resource "aws_codedeploy_app" "this" {
  name = "${local.app_name}"
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name              = "${aws_codedeploy_app.this.name}"
  deployment_group_name = "${local.app_name}"
  service_role_arn      = "${data.aws_iam_role.codedeploy.arn}"

  load_balancer_info {
    target_group_info {
      name = "${module.loadbalancer.target_group_names[0]}"
    }
  }

  ec2_tag_filter {
    key   = "deployment_group"
    type = "KEY_AND_VALUE"
    value  = "${local.app_name}"
  }
}
