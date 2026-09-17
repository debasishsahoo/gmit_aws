# 20. Configure Region

Git Bash:

```bash
export AWS_REGION=us-east-1
```

Verify:

```bash
echo $AWS_REGION
```

Expected:

```
us-east-1
```

PowerShell:

```powershell
$env:AWS_REGION="us-east-1"
```

Verify:

```powershell
$env:AWS_REGION
```

---

# 21. Create a Lab Directory

Git Bash:

```bash
mkdir aws-nginx-lab
cd aws-nginx-lab
```

Recommended structure:

```
aws-nginx-lab/
```

We will store infrastructure IDs here.

---

# 22. Create Environment Variables

Git Bash:

```bash
export AWS_REGION=us-east-1
export VPC_CIDR=10.0.0.0/16
export SUBNET_CIDR=10.0.1.0/24
export PROJECT=student-nginx-lab
```

Verify:

```bash
echo $AWS_REGION
echo $VPC_CIDR
echo $SUBNET_CIDR
echo $PROJECT
```

---

# 23. Create VPC

Command:

```bash
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications \
  'ResourceType=vpc,Tags=[{Key=Name,Value=student-nginx-vpc}]' \
  --query 'Vpc.VpcId' \
  --output text)
```

Display:

```bash
echo $VPC_ID
```

Example:

```
vpc-0123456789abcdef0
```

---

# 24. Enable DNS Hostnames

Run:

```bash
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames
```

Enable DNS support:

```bash
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support
```

Verify:

```bash
aws ec2 describe-vpcs \
  --vpc-ids $VPC_ID
```

---

# 25. Verify VPC

Run:

```bash
aws ec2 describe-vpcs \
  --vpc-ids $VPC_ID \
  --query 'Vpcs[0].[VpcId,CidrBlock,State]' \
  --output table
```

Expected:

```
-----------------------------------
|        DescribeVpcs             |
+----------------+----------------+
| vpc-xxxxxxxx   | 10.0.0.0/16    |
| available      |                |
+----------------+----------------+
```

---

# 26. Create Public Subnet

Run:

```bash
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications \
  'ResourceType=subnet,Tags=[{Key=Name,Value=student-nginx-public-subnet}]' \
  --query 'Subnet.SubnetId' \
  --output text)
```

Verify:

```bash
echo $SUBNET_ID
```

---

# 27. Enable Public IPv4 Assignment

Run:

```bash
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch
```

This means instances launched in this subnet can automatically receive public IPv4 addresses.

---

# 28. Verify Subnet

```bash
aws ec2 describe-subnets \
  --subnet-ids $SUBNET_ID \
  --query 'Subnets[0].[SubnetId,VpcId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' \
  --output table
```

Expected:

```
Subnet:
10.0.1.0/24

Availability Zone:
us-east-1a

Public IP:
True
```

---

# 29. Create Internet Gateway

Run:

```bash
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications \
  'ResourceType=internet-gateway,Tags=[{Key=Name,Value=student-nginx-igw}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
```

Verify:

```bash
echo $IGW_ID
```

---

# 30. Attach Internet Gateway to VPC

Run:

```bash
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID
```

Verify:

```bash
aws ec2 describe-internet-gateways \
  --internet-gateway-ids $IGW_ID
```

Important:

The IGW must be attached to the VPC.

---

# 31. Create Route Table

Run:

```bash
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications \
  'ResourceType=route-table,Tags=[{Key=Name,Value=student-nginx-public-rt}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)
```

Verify:

```bash
echo $RTB_ID
```

---

# 32. Create Internet Route

Run:

```bash
aws ec2 create-route \
  --route-table-id $RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID
```

This creates:

```
0.0.0.0/0
      |
      v
Internet Gateway
```

---

# 33. Associate Route Table with Subnet

Run:

```bash
ASSOCIATION_ID=$(aws ec2 associate-route-table \
  --route-table-id $RTB_ID \
  --subnet-id $SUBNET_ID \
  --query 'AssociationId' \
  --output text)
```

Verify:

```bash
echo $ASSOCIATION_ID
```

---

# 34. Verify Routes

Run:

```bash
aws ec2 describe-route-tables \
  --route-table-ids $RTB_ID \
  --query 'RouteTables[0].Routes[*].[DestinationCidrBlock,GatewayId,State]' \
  --output table
```

Expected conceptually:

```
Destination       Target

10.0.0.0/16       local
0.0.0.0/0         igw-xxxxxxxx
```

---

# 35. Create Security Group

Run:

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name student-nginx-sg \
  --description "Security group for student Nginx web server" \
  --vpc-id $VPC_ID \
  --tag-specifications \
  'ResourceType=security-group,Tags=[{Key=Name,Value=student-nginx-sg}]' \
  --query 'GroupId' \
  --output text)
```

Verify:

```bash
echo $SG_ID
```

---

# 36. Security Group Rules

We require:

```
SSH  -> TCP 22
HTTP -> TCP 80
```

---

# 37. Determine Student Public IP

From Git Bash:

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)
```

Verify:

```bash
echo $MY_IP
```

Example:

```
203.0.113.25
```

Do NOT use the example address.

---

# 38. Allow SSH Only From Student IP

Run:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

The `/32` means:

```
Only this single public IPv4 address
```

This is significantly safer than:

```
0.0.0.0/0
```

for SSH.

---

# 39. Allow HTTP From Internet

Run:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

This allows public web traffic.

---

# 40. Verify Security Group

```bash
aws ec2 describe-security-groups \
  --group-ids $SG_ID
```

Expected inbound rules:

```
TCP 22
Source: YOUR_IP/32

TCP 80
Source: 0.0.0.0/0
```

---

# 41. Create EC2 Key Pair

The key pair is required for SSH access.

Create:

```bash
aws ec2 create-key-pair \
  --key-name student-nginx-key \
  --query 'KeyMaterial' \
  --output text > student-nginx-key.pem
```

Check:

```bash
ls -l student-nginx-key.pem
```

---

# 42. Protect the Private Key

Git Bash:

```bash
chmod 400 student-nginx-key.pem
```

Verify:

```bash
ls -l student-nginx-key.pem
```

The key must not be publicly readable.

Never upload this file to GitHub.

Add it to `.gitignore` if the directory is a Git repository:

```
*.pem
```

---
# 43. Obtain Amazon Linux 2023 AMI

Do NOT hard-code an old AMI ID.

AMI IDs vary by region and can change over time.

AWS provides a public Systems Manager parameter for Amazon Linux 2023.

Run:

```bash
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --region $AWS_REGION \
  --query 'Parameter.Value' \
  --output text)
```

```bash
aws ec2 describe-images \
  --region ap-south-1 \
  --owners amazon \
  --filters \
    "Name=name,Values=al2023*" \
    "Name=state,Values=available" \
    "Name=architecture,Values=x86_64" \
  --query 'Images | sort_by(@, &CreationDate) | [-10:].[ImageId,Name,CreationDate]' \
  --output table
```

Verify:

```bash
echo $AMI_ID
```

---

# 44. Create EC2 User Data

We want Nginx installed automatically when the EC2 instance starts.

Create:

```bash
nano user-data.sh
```

Put:

```bash
#!/bin/bash

dnf update -y

dnf install -y nginx git

systemctl enable nginx
systemctl start nginx

mkdir -p /var/www/student-site

chown -R nginx:nginx /var/www/student-site
chmod -R 755 /var/www/student-site

cat > /var/www/student-site/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>AWS Nginx Lab</title>
</head>
<body>
    <h1>AWS Nginx Web Server</h1>
    <p>Website deployed successfully.</p>
</body>
</html>
EOF

cat > /etc/nginx/conf.d/student-site.conf <<'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/student-site;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

nginx -t

systemctl restart nginx
```

---

# 45. Why User Data Is Useful

User Data allows initialization commands to run during EC2 startup.

Instead of manually executing:

```
Install Nginx
Install Git
Create directories
Configure Nginx
Start Nginx
```

we can automate them.

This is an important DevOps principle:

```
Manual configuration
        |
        v
Automation
        |
        v
Repeatable infrastructure
```

---

# 46. Launch EC2 Instance

Run:

```bash
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name student-nginx-key \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --associate-public-ip-address \
  --user-data file://user-data.sh \
  --tag-specifications \
  'ResourceType=instance,Tags=[{Key=Name,Value=student-nginx-server}]' \
  --query 'Instances[0].InstanceId' \
  --output text)
```

Verify:

```bash
echo $INSTANCE_ID
```

---

# 47. Wait for EC2 to Become Ready

Run:

```bash
aws ec2 wait instance-running \
  --instance-ids $INSTANCE_ID
```

Then:

```bash
aws ec2 wait instance-status-ok \
  --instance-ids $INSTANCE_ID
```

This prevents students from attempting SSH before the operating system is ready.

---

# 48. Get Public IP

Run:

```bash
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)
```

Display:

```bash
echo $PUBLIC_IP
```

Example:

```
54.xx.xx.xx
```

---

# 49. Get Complete EC2 Information

Run:

```bash
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress,SubnetId,VpcId]' \
  --output table
```

Students should record:

```
Instance ID
Instance State
Private IP
Public IP
Subnet ID
VPC ID
```

---

# 50. Connect to EC2 Using SSH

Amazon Linux 2023 normally uses:

```
ec2-user
```

SSH command:

```bash
ssh -i student-nginx-key.pem ec2-user@$PUBLIC_IP
```

If asked:

```
Are you sure you want to continue connecting?
```

type:

```
yes
```

---

# 51. Verify Operating System

Inside EC2:

```bash
cat /etc/os-release
```

Expected to show Amazon Linux.

Also run:

```bash
uname -a
```

---

# 52. Verify Nginx

Run:

```bash
sudo systemctl status nginx
```

Expected:

```
Active: active (running)
```

If Nginx is not running:

```bash
sudo systemctl start nginx
```

Enable it permanently:

```bash
sudo systemctl enable nginx
```

---

# 53. Verify Nginx Version

```bash
nginx -v
```

---

# 54. Verify HTTP Locally

Inside EC2:

```bash
curl http://localhost
```

Expected:

```html
<!DOCTYPE html>
<html>
...
```

This proves that Nginx is responding locally.

---

# 55. Test Nginx From the Internet

From the student’s Windows machine:

```bash
curl http://$PUBLIC_IP
```

Or open:

```
http://PUBLIC_IP
```

in a web browser.

At this stage the default/test page should appear.

---