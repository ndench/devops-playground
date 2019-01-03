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

CodeDeploy will only automatically deploy on boot to it's registered autoscaling group, not instances
registed through tags.

When a new launch configuration is created, a new autoscaling group is created. CodeDeploy doesn't
know about this autoscaling group, until the creation has completed successfully. The instances in
the group won't be automatically deployed to because they have already booted before CodeDeploy
learns of the autoscaling group.

If the autoscaling group is configured to use the loadbalancer for health checks, the creation will
never succeed, because the instance won't be healthy - CodeDeploy didn't know about the autoscaling
group when the instance was booted.

To get CodeDeploy to deploy to a new instance, you use the aws cli with
--update-outdated-instances-only, except running this is user-data means it likely runs before the
tags are applied to the instance and code deploy to realise the instance is in the deployment group.
So you have to make it sleep for a bit and hope it's added to the deployment group when you run the
command.

<https://kevsoft.net/2017/10/20/deploying-multiple-applications-to-an-auto-scaling-group-with-codedeploy.html>


## Steps

1. Create a new autoscaling group when launch configuration changes - delete the old one
2. Instances in new autoscaling group aren't deployed to
3. Make autoscaling group use load balancer health checks to prevent downtime with un-deployed
   instances
4. Infinite loop of killing and creating instances because none are being deployed to
5. Realise that code deploy doesn't update to use the new autoscaling group until groups has been
   created successfully, the group isn't created successfully until it's healthy, it's not healthy
   until the instances are deployed to
6. Realise the first instances in the new autoscaling group aren't deployed to anyway, because the
   code deploy hook hasn't been created when they are booted
7. Use instance tags to register them with the deployment group
8. Realise instances registered with tags aren't auto deployed to on boot, because they don't have a
   lifecycle hook
9. Make instances deploy to themselves on boot with `aws deploy --update-outdated-instances-only`
10. Deploy fails because the instance isn't in the deployment group yet
11. Add `sleep 30s` before deploying on boot to ensure they're registered
12. :tada:
