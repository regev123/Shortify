# PowerShell Script: Test Partition Management
# Purpose: Manually trigger partition creation for testing (without waiting for scheduled task)
# Usage: .\test-partition-management.ps1 [-Months 12] [-ServiceUrl "http://localhost:8081"]

param(
    [int]$Months = 12,
    [string]$ServiceUrl = "http://localhost:8081"
)

Write-Host "=== Partition Management Test Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if Create Service is running
Write-Host "Checking Create Service health..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "$ServiceUrl/actuator/health" -Method Get -TimeoutSec 5
    if ($healthResponse.status -eq "UP") {
        Write-Host "[OK] Create Service is running" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Create Service is not healthy" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[ERROR] Cannot connect to Create Service at $ServiceUrl" -ForegroundColor Red
    Write-Host "  Make sure the Create Service is running on port 8081" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Get current partition statistics
Write-Host "Current partition statistics:" -ForegroundColor Yellow
try {
    $statsResponse = Invoke-RestMethod -Uri "$ServiceUrl/api/v1/create/admin/partitions/stats" -Method Get -TimeoutSec 5
    Write-Host $statsResponse -ForegroundColor White
} catch {
    Write-Host "  Could not retrieve statistics: $_" -ForegroundColor Yellow
}

Write-Host ""

# Create partitions for next N months
Write-Host "Creating partitions for next $Months months..." -ForegroundColor Yellow
try {
    $createResponse = Invoke-RestMethod -Uri "$ServiceUrl/api/v1/create/admin/partitions/create-next-months?months=$Months" -Method Post -TimeoutSec 30
    Write-Host "[OK] $createResponse" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Error creating partitions: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "  Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""

# Get updated partition statistics
Write-Host "Updated partition statistics:" -ForegroundColor Yellow
try {
    $statsResponse = Invoke-RestMethod -Uri "$ServiceUrl/api/v1/create/admin/partitions/stats" -Method Get -TimeoutSec 5
    Write-Host $statsResponse -ForegroundColor White
} catch {
    Write-Host "  Could not retrieve statistics: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""

# Explicitly exit with success code
exit 0

