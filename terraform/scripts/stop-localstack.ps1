# PowerShell script to stop LocalStack

Write-Host "Stopping LocalStack..." -ForegroundColor Yellow

# Check if LocalStack container exists
$container = docker ps -a --filter "name=localstack" --format "{{.Names}}"
if ($container -eq "localstack") {
    docker stop localstack
    Write-Host "✓ LocalStack stopped" -ForegroundColor Green
    
    $remove = Read-Host "Do you want to remove the container? (y/n)"
    if ($remove -eq "y" -or $remove -eq "Y") {
        docker rm localstack
        Write-Host "✓ LocalStack container removed" -ForegroundColor Green
    }
} else {
    Write-Host "LocalStack container not found" -ForegroundColor Yellow
}

