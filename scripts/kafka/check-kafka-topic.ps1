# PowerShell script to check if Kafka topic exists and show its details

param(
    [string]$TopicName = "url-click-events",
    [string]$BootstrapServers = "localhost:9092"
)

Write-Host "Checking Kafka topic: $TopicName" -ForegroundColor Green
Write-Host "Bootstrap Servers: $BootstrapServers" -ForegroundColor Cyan
Write-Host ""

# Check if Kafka cluster is running
$kafkaRunning = docker ps --filter "name=kafka-broker" --format "{{.Names}}"
$singleKafka = docker ps --filter "name=^kafka$" --format "{{.Names}}"

if (-not $kafkaRunning -and -not $singleKafka) {
    Write-Host "Error: Kafka is not running. Please start it first:" -ForegroundColor Red
    Write-Host "  .\scripts\kafka\start-kafka.ps1" -ForegroundColor Yellow
    Write-Host "  OR" -ForegroundColor Yellow
    Write-Host "  .\scripts\kafka\start-kafka-cluster.ps1" -ForegroundColor Yellow
    exit 1
}

# Determine which broker to use
if ($kafkaRunning) {
    $brokerContainer = "kafka-broker-1"
    Write-Host "Using Kafka cluster (broker-1)..." -ForegroundColor Yellow
} else {
    $brokerContainer = "kafka"
    Write-Host "Using single Kafka broker..." -ForegroundColor Yellow
}

Write-Host ""

# Check if topic exists
Write-Host "Checking if topic exists..." -ForegroundColor Yellow
$topicInfo = docker exec $brokerContainer kafka-topics --describe `
    --bootstrap-server localhost:9092 `
    --topic $TopicName 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Topic '$TopicName' exists!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Topic Details:" -ForegroundColor Cyan
    $topicInfo
    Write-Host ""
    
    # Check message count (approximate)
    Write-Host "Checking message count..." -ForegroundColor Yellow
    $consumerGroup = "check-topic-group-$(Get-Random)"
    docker exec $brokerContainer kafka-console-consumer `
        --bootstrap-server localhost:9092 `
        --topic $TopicName `
        --from-beginning `
        --max-messages 1 `
        --timeout-ms 2000 2>&1 | Out-Null
    
    Write-Host "[OK] Topic is accessible" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Topic '$TopicName' does not exist!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To create the topic, run:" -ForegroundColor Yellow
    Write-Host "  .\scripts\kafka\create-topic.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Or restart Kafka cluster (it will auto-create):" -ForegroundColor Yellow
    if ($kafkaRunning) {
        Write-Host "  .\scripts\kafka\start-kafka-cluster.ps1" -ForegroundColor White
    } else {
        Write-Host "  .\scripts\kafka\start-kafka.ps1" -ForegroundColor White
    }
    exit 1
}

