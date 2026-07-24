#!/usr/bin/env bash
set -e

# AWS Infrastructure Provisioning Script for AgricConnect Backend
AWS_REGION="${AWS_REGION:-eu-west-1}"
PUBLIC_BUCKET_NAME="${PUBLIC_BUCKET_NAME:-agriconnect-public-assets}"
PRIVATE_BUCKET_NAME="${PRIVATE_BUCKET_NAME:-agriconnect-private-docs}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-agriconnect-backend}"

echo "========================================="
echo "🚀 Provisioning AgricConnect AWS Infrastructure"
echo "Region: $AWS_REGION"
echo "========================================="

# 1. Create ECR Repository
echo -e "\n1. Creating Amazon ECR Repository ($ECR_REPOSITORY_NAME)..."
aws ecr create-repository \
    --repository-name "$ECR_REPOSITORY_NAME" \
    --region "$AWS_REGION" \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 || true

# 2. Create S3 Buckets
echo -e "\n2. Creating Amazon S3 Public Asset Bucket ($PUBLIC_BUCKET_NAME)..."
aws s3api create-bucket \
    --bucket "$PUBLIC_BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION" || true

echo -e "\n3. Creating Amazon S3 Private Document Bucket ($PRIVATE_BUCKET_NAME)..."
aws s3api create-bucket \
    --bucket "$PRIVATE_BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION" || true

# Block Public Access for Private Bucket
aws s3api put-public-access-block \
    --bucket "$PRIVATE_BUCKET_NAME" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Configure CORS on Public Bucket for Direct Presigned Uploads from Mobile App
cat <<'EOF' > /tmp/cors-config.json
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
      "AllowedOrigins": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF
aws s3api put-bucket-cors --bucket "$PUBLIC_BUCKET_NAME" --cors-configuration file:///tmp/cors-config.json
rm -f /tmp/cors-config.json

# 4. Create IAM User & Policy for GitHub Actions
echo -e "\n4. Creating IAM Deployer User for GitHub Actions (agriconnect-github-deployer)..."
aws iam create-user --user-name agriconnect-github-deployer || true

# Attach Policy for ECR and App Runner Access
cat <<'EOF' > /tmp/policy-config.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "apprunner:StartDeployment",
        "apprunner:DescribeService"
      ],
      "Resource": "*"
    }
  ]
}
EOF
aws iam create-policy --policy-name AgricConnectDeployerPolicy --policy-document file:///tmp/policy-config.json || true
rm -f /tmp/policy-config.json

# Attach Policy to User
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam attach-user-policy --user-name agriconnect-github-deployer --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/AgricConnectDeployerPolicy" || true

# Create Access Keys for GitHub Actions
echo -e "\n🔑 Generating Access Keys for GitHub Secrets..."
aws iam create-access-key --user-name agriconnect-github-deployer

echo "========================================="
echo "✅ AWS Infrastructure Setup Complete!"
echo "Add the printed AccessKeyId and SecretAccessKey to your GitHub Repository Secrets."
echo "========================================="
