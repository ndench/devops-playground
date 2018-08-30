variable "region" {
  type        = "string"
  description = "AWS region to create resources"
  default     = "ap-southeast-1"
}

variable "availability_zones" {
  type        = "list"
  description = "AZs to us"
  default     = [
    "ap-southeast-1a",
    "ap-southeast-1b",
    "ap-southeast-1c",
  ]
}

variable "web_ami_name" {
  type        = "string"
  description = "Name to use to find the latest web AMI"
  default     = "devops-playground-web"
}

variable "ssh_key_name" {
  type        = "string"
  description = "Name of the SSH key to assign to instances"
}
