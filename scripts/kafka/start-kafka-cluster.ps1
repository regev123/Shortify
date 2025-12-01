# PowerShell script to start Kafka Cluster (3 brokers) using Docker Compose
# Usage: .\start-kafka-cluster.ps1 [-CleanVolumes]
#   -CleanVolumes: Remove all volumes for a completely fresh start (WARNING: This deletes all Kafka data)

param(
    [switch]$CleanVolumes = $false
)

Write-Host "Starting Kafka Cluster (3 brokers)..." -ForegroundColor Green

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$composeFile = Join-Path $scriptPath "docker-compose-kafka-cluster.yml"

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "Error: Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Stop any existing Kafka containers to avoid port conflicts and clean Zookeeper state
Write-Host "Checking for existing Kafka containers..." -ForegroundColor Yellow
$existingCluster = docker ps -a --filter "name=kafka-broker" --format "{{.Names}}"
$existingSingle = docker ps -a --filter "name=^kafka$" --format "{{.Names}}"

if ($existingCluster -or $existingSingle) {
    Write-Host "Stopping existing Kafka containers and cleaning up..." -ForegroundColor Yellow
    
    # Properly stop the cluster using docker-compose to clean Zookeeper state
    if ($CleanVolumes) {
        Write-Host "Removing volumes for fresh start..." -ForegroundColor Yellow
        docker-compose -f $composeFile down -v 2>$null
    } else {
        docker-compose -f $composeFile down 2>$null
    }
    
    # Also stop single broker if it exists
    if ($existingSingle) {
        docker stop kafka 2>$null
        docker rm kafka 2>$null
    }
    
    Write-Host "Waiting for cleanup to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

# Start Kafka Cluster
Write-Host "Starting Zookeeper and Kafka Cluster (3 brokers)..." -ForegroundColor Yellow
docker-compose -f $composeFile up -d --remove-orphans

Write-Host "Waiting for Kafka Cluster to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check if Zookeeper is running
$zookeeperStatus = docker ps --filter "name=kafka-zookeeper" --format "{{.Status}}"
if ($zookeeperStatus) {
    Write-Host "[OK] Zookeeper is running!" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Zookeeper failed to start" -ForegroundColor Red
}

# Check if all Kafka brokers are running
$broker1Status = docker ps --filter "name=kafka-broker-1" --format "{{.Status}}"
$broker2Status = docker ps --filter "name=kafka-broker-2" --format "{{.Status}}"
$broker3Status = docker ps --filter "name=kafka-broker-3" --format "{{.Status}}"

$allBrokersRunning = $broker1Status -and $broker2Status -and $broker3Status

if ($allBrokersRunning) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Kafka Cluster is running!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Create the url-click-events topic
    Write-Host "Creating Kafka topic: url-click-events..." -ForegroundColor Yellow
    docker exec kafka-broker-1 kafka-topics --create `
        --bootstrap-server localhost:9092 `
        --topic url-click-events `
        --partitions 6 `
        --replication-factor 3 `
        --if-not-exists | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Topic 'url-click-events' is ready" -ForegroundColor Green
    } else {
        # Topic might already exist, check if it's accessible
        docker exec kafka-broker-1 kafka-topics --describe `
            --bootstrap-server localhost:9092 `
            --topic url-click-events | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Topic 'url-click-events' already exists" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Could not verify topic. You may need to create it manually:" -ForegroundColor Yellow
            Write-Host "  .\scripts\kafka\create-topic.ps1" -ForegroundColor White
        }
    }
    
    # Create the url-deleted-events topic
    Write-Host "Creating Kafka topic: url-deleted-events..." -ForegroundColor Yellow
    docker exec kafka-broker-1 kafka-topics --create `
        --bootstrap-server localhost:9092 `
        --topic url-deleted-events `
        --partitions 6 `
        --replication-factor 3 `
        --if-not-exists | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Topic 'url-deleted-events' is ready" -ForegroundColor Green
    } else {
        docker exec kafka-broker-1 kafka-topics --describe `
            --bootstrap-server localhost:9092 `
            --topic url-deleted-events | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Topic 'url-deleted-events' already exists" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Could not verify url-deleted-events topic" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "Kafka Brokers:" -ForegroundColor Cyan
    Write-Host "  - Broker 1: localhost:9092" -ForegroundColor White
    Write-Host "  - Broker 2: localhost:9093" -ForegroundColor White
    Write-Host "  - Broker 3: localhost:9094" -ForegroundColor White
    Write-Host ""
    Write-Host "Bootstrap Servers (for clients):" -ForegroundColor Cyan
    Write-Host "  localhost:9092,localhost:9093,localhost:9094" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Kafka UI: http://localhost:8084" -ForegroundColor Cyan
    Write-Host "Zookeeper: localhost:2181" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Cluster Configuration:" -ForegroundColor Cyan
    Write-Host "  - Replication Factor: 3" -ForegroundColor White
    Write-Host "  - Min In-Sync Replicas: 2" -ForegroundColor White
    Write-Host "  - Default Partitions: 6" -ForegroundColor White
    Write-Host "  - Can tolerate 1 broker failure" -ForegroundColor White
    Write-Host ""
    Write-Host "To stop Kafka Cluster, run:" -ForegroundColor Yellow
    Write-Host "  docker-compose -f $composeFile down" -ForegroundColor White
    Write-Host ""
    Write-Host "To stop and remove all data (fresh start), run:" -ForegroundColor Yellow
    Write-Host "  docker-compose -f $composeFile down -v" -ForegroundColor White
    Write-Host ""
    Write-Host "To view logs, run:" -ForegroundColor Yellow
    Write-Host "  docker-compose -f $composeFile logs -f" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "Error: Some Kafka brokers failed to start." -ForegroundColor Red
    Write-Host ""
    if ($broker1Status) {
        Write-Host "[OK] Broker 1 is running" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Broker 1 failed to start" -ForegroundColor Red
    }
    if ($broker2Status) {
        Write-Host "[OK] Broker 2 is running" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Broker 2 failed to start" -ForegroundColor Red
    }
    if ($broker3Status) {
        Write-Host "[OK] Broker 3 is running" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Broker 3 failed to start" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Check logs with: docker-compose -f $composeFile logs" -ForegroundColor Yellow
    exit 1
}
