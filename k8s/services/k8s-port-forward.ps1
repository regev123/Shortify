# Helper script to set up port-forward for Kubernetes services
# Run this in a separate terminal before running load tests or accessing services

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Kubernetes Port-Forward Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Select service to port-forward:" -ForegroundColor Yellow
Write-Host "  1. API Gateway (localhost:8080)" -ForegroundColor White
Write-Host "  2. Redis Cluster (localhost:6379)" -ForegroundColor White
Write-Host "  3. Both (in separate windows)" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter choice (1-3)"

switch ($choice) {
    "1" {
        Write-Host "`nSetting up port-forward for API Gateway..." -ForegroundColor Yellow
        Write-Host "This will forward localhost:8080 to api-gateway service`n" -ForegroundColor Gray
        Write-Host "Press Ctrl+C to stop port-forwarding`n" -ForegroundColor Yellow
        kubectl port-forward svc/api-gateway 8080:8080 -n shortify
    }
    "2" {
        Write-Host "`nSetting up port-forward for Redis Cluster..." -ForegroundColor Yellow
        Write-Host "This will forward localhost:6379 to redis-cluster service`n" -ForegroundColor Gray
        Write-Host "Press Ctrl+C to stop port-forwarding`n" -ForegroundColor Yellow
        kubectl port-forward svc/redis-cluster 6379:6379 -n shortify
    }
    "3" {
        Write-Host "`nStarting port-forwards in separate windows..." -ForegroundColor Yellow
        
        # Start API Gateway port-forward in new window
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'API Gateway Port-Forward (localhost:8080)' -ForegroundColor Cyan; kubectl port-forward svc/api-gateway 8080:8080 -n shortify"
        Start-Sleep -Seconds 1
        
        # Start Redis port-forward in new window
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Redis Cluster Port-Forward (localhost:6379)' -ForegroundColor Cyan; kubectl port-forward svc/redis-cluster 6379:6379 -n shortify"
        
        Write-Host "`n[OK] Port-forwards started in separate windows!" -ForegroundColor Green
        Write-Host "  - API Gateway: localhost:8080" -ForegroundColor White
        Write-Host "  - Redis Cluster: localhost:6379" -ForegroundColor White
        Write-Host "`nClose the windows to stop port-forwarding." -ForegroundColor Gray
    }
    default {
        Write-Host "Invalid choice. Exiting." -ForegroundColor Red
        exit 1
    }
}

