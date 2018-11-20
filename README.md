# DevOps Playground

This project is meant to be used to test and play with different devops concepts succh as:

- Terraform
- Ansible
- Packer
- AWS

## Setup

In order to use the playground, you'll need a few things installed:

- [Terraform](https://terraform.io)
- [Packer](https://packer.io)
- [AWS cli](https://aws.amazon.com/cli/)

Make sure you configure the AWS cli with a access key and secret key that give
it access to create and destroy resources:

```sh
$ aws configure
```

Deploy a new revision:

```sh
$ ./deploy.sh <S3 Bucket Name>
```

Build a new ami:

```sh
$ packer build packer.json
```

Deploy the new ami:

```sh
$ terraform apply
```

## Notes

With autoscaling group set on deployment group, new autoscaling instances will get the application
deployed, but the first instance doesn't get deployed.

Without the autoscaling group set but using tags, instances don't get deployed to when they boot.

