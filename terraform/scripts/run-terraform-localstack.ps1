# PowerShell script to run Terraform with LocalStack
# This script automates the entire Terraform workflow for LocalStack

param(
    [switch]$PlanOnly,
    [switch]$Destroy
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Terraform + LocalStack Automation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set AWS credentials for LocalStack (dummy credentials)
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"

Write-Host "Set AWS credentials for LocalStack" -ForegroundColor Green

# Check if LocalStack is running
Write-Host "Checking LocalStack..." -ForegroundColor Yellow
$localstack = docker ps --filter "name=localstack" --format "{{.Names}}" 2>$null
if ($localstack -ne "localstack") {
    Write-Host "WARNING: LocalStack container not found!" -ForegroundColor Red
    Write-Host "Please start LocalStack first:" -ForegroundColor Yellow
    Write-Host "  cd scripts" -ForegroundColor White
    Write-Host "  .\start-localstack.ps1" -ForegroundColor White
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        exit 1
    }
} else {
    Write-Host "LocalStack is running" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 1: Initialize Terraform" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Navigate to terraform directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$terraformDir = Join-Path $scriptPath ".."
Set-Location $terraformDir

# Initialize Terraform
Write-Host "Running terraform init..." -ForegroundColor Yellow
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform init failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($Destroy) {
    Write-Host "Step 2: Destroy Infrastructure" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "WARNING: This will destroy all resources!" -ForegroundColor Red
    $confirm = Read-Host "Type 'yes' to confirm"
    
    if ($confirm -eq "yes") {
        Write-Host ""
        Write-Host "Destroying infrastructure..." -ForegroundColor Yellow
        terraform destroy -var-file="environments/local/terraform.tfvars" -auto-approve
        Write-Host ""
        Write-Host "Infrastructure destroyed!" -ForegroundColor Green
    } else {
        Write-Host "Destroy cancelled." -ForegroundColor Yellow
    }
    exit 0
}

Write-Host "Step 2: Plan Infrastructure" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Plan Terraform - output will stream directly
Write-Host "Analyzing infrastructure (this may take a minute)..." -ForegroundColor Yellow
Write-Host ""

# Run terraform plan - output streams directly (no buffering)
terraform plan -var-file="environments/local/terraform.tfvars"

$planExitCode = $LASTEXITCODE

Write-Host ""

if ($planExitCode -ne 0) {
    Write-Host "ERROR: Terraform plan failed!" -ForegroundColor Red
    Write-Host "Check the errors above and fix them." -ForegroundColor Yellow
    exit 1
}

Write-Host "Plan completed successfully!" -ForegroundColor Green

if ($PlanOnly) {
    Write-Host ""
    Write-Host "Plan completed (plan-only mode)." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 3: Apply Infrastructure" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Confirm apply
Write-Host "Ready to create infrastructure in LocalStack." -ForegroundColor Yellow
$confirm = Read-Host "Type 'yes' to proceed"

if ($confirm -ne "yes") {
    Write-Host "Apply cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Creating infrastructure (this may take several minutes)..." -ForegroundColor Yellow
Write-Host ""

# Run apply - output streams directly (no buffering)
terraform apply -var-file="environments/local/terraform.tfvars" -auto-approve

$applyExitCode = $LASTEXITCODE

Write-Host ""

if ($applyExitCode -ne 0) {
    Write-Host "ERROR: Terraform apply failed!" -ForegroundColor Red
    Write-Host "Check the errors above." -ForegroundColor Yellow
    exit 1
}

Write-Host "Apply completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 4: View Outputs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Show outputs
Write-Host ""
Write-Host "Infrastructure outputs:" -ForegroundColor Green
terraform output

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Success! Infrastructure deployed to LocalStack" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Yellow
Write-Host "  View outputs: terraform output" -ForegroundColor White
Write-Host "  Destroy all:  .\scripts\run-terraform-localstack.ps1 -Destroy" -ForegroundColor White
Write-Host "  Plan only:    .\scripts\run-terraform-localstack.ps1 -PlanOnly" -ForegroundColor White
