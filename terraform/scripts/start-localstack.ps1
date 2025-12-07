Write-Host "Starting LocalStack for Terraform development..." -ForegroundColor Green

docker rm -f localstack 2>$null

Write-Host "Starting LocalStack container..." -ForegroundColor Yellow
docker run -d --name localstack -p 4566:4566 -p 4571:4571 -e SERVICES=ec2,s3,rds,elasticache,kafka,eks,elbv2,iam,logs,cloudwatch localstack/localstack

Write-Host "Waiting for LocalStack to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$running = docker ps --filter "name=localstack" --format "{{.Names}}" 2>$null
if ($running -eq "localstack") {
    Write-Host "LocalStack is running!" -ForegroundColor Green
    Write-Host "Endpoint: http://localhost:4566" -ForegroundColor Cyan
} else {
    Write-Host "LocalStack failed to start. Check logs: docker logs localstack" -ForegroundColor Red
}
