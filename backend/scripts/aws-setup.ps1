# AWS Infrastructure Provisioning Script for AgricConnect Backend
# Region: eu-west-1 (Default)

Param(
    [string]$AwsRegion = "eu-west-1",
    [string]$PublicBucketName = "agriconnect-public-assets",
    [string]$PrivateBucketName = "agriconnect-private-docs",
    [string]$EcrRepositoryName = "agriconnect-backend"
)

Write-Host "=========================================" -ForegroundColor Green
Write-Host "🚀 Provisioning AgricConnect AWS Infrastructure" -ForegroundColor Green
Write-Host "Region: $AwsRegion" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Green

# 1. Create ECR Repository
Write-Host "`n1. Creating Amazon ECR Repository ($EcrRepositoryName)..." -ForegroundColor Cyan
aws ecr create-repository `
    --repository-name $EcrRepositoryName `
    --region $AwsRegion `
    --image-scanning-configuration scanOnPush=true `
    --encryption-configuration encryptionType=AES256

# 2. Create S3 Buckets
Write-Host "`n2. Creating Amazon S3 Public Asset Bucket ($PublicBucketName)..." -ForegroundColor Cyan
aws s3api create-bucket `
    --bucket $PublicBucketName `
    --region $AwsRegion `
    --create-bucket-configuration LocationConstraint=$AwsRegion

Write-Host "`n3. Creating Amazon S3 Private Document Bucket ($PrivateBucketName)..." -ForegroundColor Cyan
aws s3api create-bucket `
    --bucket $PrivateBucketName `
    --region $AwsRegion `
    --create-bucket-configuration LocationConstraint=$AwsRegion

# Block Public Access for Private Bucket
aws s3api put-public-access-block `
    --bucket $PrivateBucketName `
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Configure CORS on Public Bucket for Direct Presigned Uploads from Mobile App
$corsJson = '{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
      "AllowedOrigins": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}'
$corsJson | Out-File -FilePath "./cors-temp.json" -Encoding utf8
aws s3api put-bucket-cors --bucket $PublicBucketName --cors-configuration file://cors-temp.json
Remove-Item "./cors-temp.json" -ErrorAction SilentlyContinue

# 4. Create IAM User & Policy for GitHub Actions
Write-Host "`n4. Creating IAM Deployer User for GitHub Actions (agriconnect-github-deployer)..." -ForegroundColor Cyan
aws iam create-user --user-name agriconnect-github-deployer

# Attach Policy for ECR and App Runner Access
$policyJson = '{
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
}'
$policyJson | Out-File -FilePath "./policy-temp.json" -Encoding utf8
aws iam create-policy --policy-name AgricConnectDeployerPolicy --policy-document file://policy-temp.json
Remove-Item "./policy-temp.json" -ErrorAction SilentlyContinue

# Attach Policy to User
$accountNumber = (aws sts get-caller-identity --query Account --output text)
aws iam attach-user-policy --user-name agriconnect-github-deployer --policy-arn "arn:aws:iam::${accountNumber}:policy/AgricConnectDeployerPolicy"

# Create Access Keys for GitHub Actions
Write-Host "`n🔑 Generating Access Keys for GitHub Secrets..." -ForegroundColor Yellow
aws iam create-access-key --user-name agriconnect-github-deployer

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "✅ AWS Infrastructure Setup Complete!" -ForegroundColor Green
Write-Host "Add the printed AccessKeyId and SecretAccessKey to your GitHub Repository Secrets." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Green
