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

Make sure the artifact exists in s3:

```sh
$ cd artifact
$ zip -r ../artifact.zip *
$ cd ..
$ aws s3 cp artifact.zip s3://sunfish-all-general/test/devops-playgound.zip
```

Create an application revision:

```sh
$ aws deploy register-application-revision --application-name devops-playground --s3-location bucket=sunfish-all-general,bundleType=zip,key=test/devops-playground.zip --region ap-southeast-1
```

## TODO:

- Get codedeploy to deploy a revision
- Remove default nginx html
