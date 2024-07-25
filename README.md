# ec2-openvpn-no-ip
Terraform to deploy my personal openvpn server into aws. Uses NO-IP ddns to ensure that the client can find the ec2 instance public ip. Creates an ami image to then run off of that ami.

# config
| Variable Name        | Description                                                                 |
|----------------------|-----------------------------------------------------------------------------|
| ACTION_ASSUME_ROLE   | The role to assume in AWS, typically used for gaining specific permissions. |
| AWS_DEFAULT_REGION   | The default region to be used for AWS services.                             |
| NOIP_DOMAIN          | The domain name used with the No-IP dynamic DNS service.                    |
| NOIP_PASSWORD        | The password for the No-IP account.                                         |
| NOIP_USERNAME        | The username for the No-IP account.                                         |
| SSH_PUBLIC_KEY       | The public SSH key used for secure access.                                  |
| TF_BACKEND_BUCKET    | The S3 bucket used for storing Terraform state files.                       |

# rules
- ASG scales down automatically at 7PM.

# todo
- The autoscaling rule that scales down the asg could perhaps monitor the traffic in the ec2 instance and only scales down if the traffic has been low for a number of hours.
