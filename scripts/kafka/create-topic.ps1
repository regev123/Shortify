# PowerShell script to create Kafka topic for click events
# This ensures the topic exists before services start consuming

param(
    [string]$TopicName = "url-click-events",
    [int]$Partitions = 6,
    [int]$ReplicationFactor = 3,
    [string]$BootstrapServers = "localhost:9092"
)

Write-Host "Creating Kafka topic: $TopicName" -ForegroundColor Green

# Check if Kafka cluster is running
$kafkaRunning = docker ps --filter "name=kafka-broker-1" --format "{{.Names}}"
if (-not $kafkaRunning) {
    Write-Host "Error: Kafka cluster is not running. Please start it first:" -ForegroundColor Red
    Write-Host "  .\scripts\kafka\start-kafka-cluster.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Waiting for Kafka brokers to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Create topic using kafka-topics inside the broker container
Write-Host "Creating topic with:" -ForegroundColor Cyan
Write-Host "  Topic: $TopicName" -ForegroundColor White
Write-Host "  Partitions: $Partitions" -ForegroundColor White
Write-Host "  Replication Factor: $ReplicationFactor" -ForegroundColor White
Write-Host "  Bootstrap Servers: $BootstrapServers" -ForegroundColor White
Write-Host ""

# Use kafka-broker-1 to create the topic
docker exec kafka-broker-1 kafka-topics --create `
    --bootstrap-server localhost:9092 `
    --topic $TopicName `
    --partitions $Partitions `
    --replication-factor $ReplicationFactor `
    --if-not-exists

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Topic created successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Verify topic was created
    Write-Host "Verifying topic..." -ForegroundColor Yellow
    docker exec kafka-broker-1 kafka-topics --describe `
        --bootstrap-server localhost:9092 `
        --topic $TopicName
    
    Write-Host ""
    Write-Host "Topic is ready for use!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Error: Failed to create topic. Check Kafka cluster status." -ForegroundColor Red
    Write-Host "Run: docker-compose -f scripts\kafka\docker-compose-kafka-cluster.yml logs" -ForegroundColor Yellow
    exit 1
}

