# ROSA Setup Guide

## Prerequisites for ROSA

### AWS Account Requirements

1. **AWS Account with appropriate permissions**
2. **Service Quotas (minimum requirements):**
   - Running On-Demand instances: 100
   - VPCs per Region: 5
   - Internet gateways per Region: 5
   - Network Load Balancers per Region: 50
   - Application Load Balancers per Region: 50

### Red Hat Account

1. **Red Hat Customer Portal account**
2. **OpenShift subscription or trial**

## Step-by-Step Setup

### 1. Install Required Tools

Run the setup script:
```bash
./setup-rosa-environment.sh
```

Or install manually:
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install AWS CLI
brew install awscli

# Install ROSA CLI
brew install rosa-cli

# Install OpenShift CLI
brew install openshift-cli

# Install kubectl
brew install kubectl
```

### 2. Configure AWS Credentials

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

### 3. Authenticate with Red Hat

```bash
rosa login
```

This will open a browser window for authentication.

### 4. Verify Setup

```bash
# Check AWS authentication
aws sts get-caller-identity

# Check ROSA authentication
rosa whoami

# Verify quotas and permissions
rosa verify quota
rosa verify permissions
```

### 5. Create Your First Cluster

```bash
./scripts/create-rosa-cluster.sh
```

## AWS IAM Permissions

Your AWS user/role needs the following permissions:

### Required AWS Services
- EC2 (full access)
- EBS (full access)
- ELB/ELBv2 (full access)
- VPC (full access)
- IAM (limited access for role creation)
- Route53 (for DNS)
- CloudFormation (for stack management)

### IAM Policy Example

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "elasticloadbalancing:*",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:PassRole",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "route53:*",
                "cloudformation:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Troubleshooting

### Common Setup Issues

1. **AWS CLI not found**
   - Install using Homebrew: `brew install awscli`

2. **ROSA CLI not found**
   - Install using Homebrew: `brew install rosa-cli`

3. **Permission denied errors**
   - Check AWS IAM permissions
   - Ensure user has necessary policies attached

4. **Quota limit errors**
   - Request quota increases in AWS Service Quotas console
   - Focus on EC2, ELB, and VPC quotas

5. **Region not supported**
   - ROSA is available in limited regions
   - Use us-east-1, us-west-2, eu-west-1, or ap-southeast-1

### Getting Help

- ROSA Documentation: https://docs.openshift.com/rosa/
- AWS Support: https://aws.amazon.com/support/
- Red Hat Support: https://access.redhat.com/support/
