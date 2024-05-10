# ec2-openvpn-no-ip

Terraform to deploy my personal openvpn server into aws

Creates an ami image to then run off of that ami.

## Todo

-   Use custom certs and signing keys so that I can deploy the same server over and over again and still have all my clients function.
-   ASG should have auto scale in policy based on time of the day, like from 9PM, it should automatically scale in as i won't be using it after 8PM.
