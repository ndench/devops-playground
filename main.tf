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

  name = "${local.app_name}-web"

  image_id             = "${data.aws_ami.web.id}"
  instance_type        = "t2.nano"
  key_name             = "${var.ssh_key_name}"
  vpc_zone_identifier  = "${module.vpc.public_subnets}"
  iam_instance_profile = "${aws_iam_role.ec2_profile.name}"
  security_groups      = [
    "${module.vpc.default_security_group_id}",
    "${module.security_group_ssh.this_security_group_id}",
    "${module.security_group_web.this_security_group_id}",
  ]

  min_size          = 1
  max_size          = 1
  desired_capacity  = 1

  target_group_arns         = ["${module.loadbalancer.target_group_arns}"]
  health_check_type         = "EC2"
  health_check_grace_period = 300
  #min_elb_capacity          = 1

  recreate_asg_when_lc_changes = true

  tags_as_map = "${local.default_tags}"

  tags = [
#    {
#      key                 = "deployment_group"
#      value               = "${local.app_name}"
#      propagate_at_launch = true
#    }
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
 * Set up CodeDeploy and IAM role for CodeDeploy
 */
data "aws_iam_policy_document" "assume_codedeploy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codedeploy_policy" {
  statement {
    actions = [
      "autoscaling:CompleteLifecycleAction",
      "autoscaling:DeleteLifecycleHook",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLifecycleHooks",
      "autoscaling:PutLifecycleHook",
      "autoscaling:RecordLifecycleActionHeartbeat",
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:EnableMetricsCollection",
      "autoscaling:DescribePolicies",
      "autoscaling:DescribeScheduledActions",
      "autoscaling:DescribeNotificationConfigurations",
      "autoscaling:SuspendProcesses",
      "autoscaling:ResumeProcesses",
      "autoscaling:AttachLoadBalancers",
      "autoscaling:PutScalingPolicy",
      "autoscaling:PutScheduledUpdateGroupAction",
      "autoscaling:PutNotificationConfiguration",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DeleteAutoScalingGroup",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:TerminateInstances",
      "tag:GetTags",
      "tag:GetResources",
      "sns:Publish",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:PutMetricAlarm",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeInstanceHealth",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]

    # TODO: Limit these to specific resources
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "codedeploy_policy" {
  name        = "${local.app_name}-codedeploy-policy"
  path        = "/service-role/"
  description = "Policy used by CodeDeploy to deploy ${local.app_name}"
  policy      = "${data.aws_iam_policy_document.codedeploy_policy.json}"
}

resource "aws_iam_role" "codedeploy" {
  name               = "${local.app_name}-codedeploy"
  description        = "Role allowing CodeDeploy to access AWS resources"
  assume_role_policy = "${data.aws_iam_policy_document.assume_codedeploy.json}"
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy_attachment" {
  role       = "${aws_iam_role.codedeploy.name}"
  policy_arn = "${aws_iam_policy.codedeploy_policy.arn}"
}

/*
 * Setup codedeploy 
 */
resource "aws_codedeploy_app" "this" {
  name = "${local.app_name}"
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name              = "${aws_codedeploy_app.this.name}"
  deployment_group_name = "${local.app_name}"
  service_role_arn      = "${aws_iam_role.codedeploy.arn}"
  autoscaling_groups    = ["${module.autoscaling.this_autoscaling_group_id}"]

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

/*
 * Setup IAM role for deployments
 */
resource "random_pet" "bucket" {
}

resource "aws_s3_bucket" "this" {
  bucket        = "${random_pet.bucket.id}"
  force_destroy = true

  tags = "${local.default_tags}"
}

data "aws_iam_policy_document" "ec2_deploy_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListObjects",
    ]

    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}

resource "aws_iam_policy" "ec2_deploy_policy" {
  name        = "${local.app_name}-ec2-deploy-policy"
  path        = "/service-role/"
  description = "Policy used by EC2 instaces to pull builds from S3"
  policy      = "${data.aws_iam_policy_document.ec2_deploy_policy.json}"
}

/*
 * Attch the policies to a role and iam instance profile to give to 
 * EC2 instances.
 */
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.app_name}-ec2-profile"
  role = "${aws_iam_role.ec2_profile.name}"
  path = "/"
}

resource "aws_iam_role" "ec2_profile" {
  name                  = "${local.app_name}-ec2-profile"
  path                  = "/"
  description           = "Role allowing an ec2 instance to access required AWS resources"
  assume_role_policy    = "${data.aws_iam_policy_document.ec2_role.json}"
}

data "aws_iam_policy_document" "ec2_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ec2_deploy_policy" {
  role       = "${aws_iam_role.ec2_profile.name}"
  policy_arn = "${aws_iam_policy.ec2_deploy_policy.arn}"
}

