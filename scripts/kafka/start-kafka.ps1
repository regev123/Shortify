# PowerShell script to start Kafka using Docker Compose

Write-Host "Starting Kafka cluster..." -ForegroundColor Green

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$composeFile = Join-Path $scriptPath "docker-compose-kafka.yml"

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "Error: Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Start Kafka
Write-Host "Starting Zookeeper and Kafka..." -ForegroundColor Yellow
docker-compose -f $composeFile up -d

Write-Host "Waiting for Kafka to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check if Kafka is running
$kafkaStatus = docker ps --filter "name=kafka" --format "{{.Status}}"
if ($kafkaStatus) {
    Write-Host "Kafka is running!" -ForegroundColor Green
    
    # Create the url-click-events topic (single broker, replication factor 1)
    Write-Host "Creating Kafka topic: url-click-events..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3  # Give Kafka a moment to fully start
    
    docker exec kafka kafka-topics --create `
        --bootstrap-server localhost:9092 `
        --topic url-click-events `
        --partitions 6 `
        --replication-factor 1 `
        --if-not-exists | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Topic 'url-click-events' is ready" -ForegroundColor Green
    } else {
        # Topic might already exist, check if it's accessible
        docker exec kafka kafka-topics --describe `
            --bootstrap-server localhost:9092 `
            --topic url-click-events | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Topic 'url-click-events' already exists" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Could not verify topic. You may need to create it manually:" -ForegroundColor Yellow
            Write-Host "  docker exec kafka kafka-topics --create --bootstrap-server localhost:9092 --topic url-click-events --partitions 6 --replication-factor 1" -ForegroundColor White
        }
    }
    
    # Create the url-deleted-events topic
    Write-Host "Creating Kafka topic: url-deleted-events..." -ForegroundColor Yellow
    docker exec kafka kafka-topics --create `
        --bootstrap-server localhost:9092 `
        --topic url-deleted-events `
        --partitions 6 `
        --replication-factor 1 `
        --if-not-exists | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Topic 'url-deleted-events' is ready" -ForegroundColor Green
    } else {
        docker exec kafka kafka-topics --describe `
            --bootstrap-server localhost:9092 `
            --topic url-deleted-events | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Topic 'url-deleted-events' already exists" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Could not verify url-deleted-events topic" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "Kafka Broker: localhost:9092" -ForegroundColor Cyan
    Write-Host "Kafka UI: http://localhost:8084" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To stop Kafka, run: docker-compose -f $composeFile down" -ForegroundColor Yellow
} else {
    Write-Host "Error: Kafka failed to start. Check logs with: docker-compose -f $composeFile logs" -ForegroundColor Red
}

