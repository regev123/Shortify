# PowerShell Script: Start All Services
# Purpose: Start all infrastructure and microservices in the correct order
# Usage: 
#   .\start-all.ps1                          # Start everything
#   .\start-all.ps1 -SkipInfrastructure      # Skip infrastructure, start from build
#   .\start-all.ps1 -SkipBuild               # Skip build, use existing artifacts
#   .\start-all.ps1 -SkipInfrastructure -SkipBuild  # Skip both, just start services

param(
    [switch]$SkipBuild = $false,
    [switch]$SkipInfrastructure = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting All Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Step 1: Start PostgreSQL with Replication
if (-not $SkipInfrastructure) {
    Write-Host "[1/6] Starting PostgreSQL with Replication..." -ForegroundColor Yellow
    $postgresScript = Join-Path (Join-Path $scriptDir "Database") "start-postgresql-with-replication.ps1"
    if (Test-Path $postgresScript) {
        # Suppress docker-compose informational stderr messages
        $oldErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        & $postgresScript 2>&1 | ForEach-Object {
            if ($_ -match "Container.*Stopping|Container.*Removing|Container.*Starting") {
                # Suppress docker-compose status messages
                return
            }
            Write-Host $_
        }
        $ErrorActionPreference = $oldErrorAction
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Failed to start PostgreSQL!" -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK] PostgreSQL is ready!" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] PostgreSQL script not found: $postgresScript" -ForegroundColor Red
        exit 1
    }

    Write-Host ""

    # Step 2: Start Kafka Cluster
    Write-Host "[2/6] Starting Kafka Cluster..." -ForegroundColor Yellow
    $kafkaScript = Join-Path (Join-Path $scriptDir "kafka") "start-kafka-cluster.ps1"
    if (Test-Path $kafkaScript) {
        $oldErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        & $kafkaScript 2>&1 | ForEach-Object {
            if ($_ -match "Container.*Stopping|Container.*Removing|Container.*Starting") {
                return
            }
            Write-Host $_
        }
        $ErrorActionPreference = $oldErrorAction
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Failed to start Kafka Cluster!" -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK] Kafka Cluster is ready!" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Kafka script not found: $kafkaScript" -ForegroundColor Red
        exit 1
    }

    Write-Host ""

    # Step 3: Start Redis Cluster
    Write-Host "[3/6] Starting Redis Cluster..." -ForegroundColor Yellow
    $redisScript = Join-Path (Join-Path $scriptDir "redis") "start-redis-cluster.ps1"
    if (Test-Path $redisScript) {
        $oldErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        & $redisScript 2>&1 | ForEach-Object {
            if ($_ -match "Container.*Stopping|Container.*Removing|Container.*Starting") {
                return
            }
            Write-Host $_
        }
        $ErrorActionPreference = $oldErrorAction
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Failed to start Redis Cluster!" -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK] Redis Cluster is ready!" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Redis script not found: $redisScript" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
} else {
    Write-Host "[SKIP] Infrastructure setup skipped (using -SkipInfrastructure)" -ForegroundColor Yellow
    Write-Host "  Assuming PostgreSQL, Kafka, and Redis are already running..." -ForegroundColor Gray
    Write-Host ""
}

# Step 4: Build project (if not skipped)
if (-not $SkipBuild) {
    $stepNumber = if ($SkipInfrastructure) { "[1/3]" } else { "[4/6]" }
    Write-Host "$stepNumber Building project..." -ForegroundColor Yellow
    Push-Location $projectRoot
    try {
        # Check for Maven Wrapper first, then Maven
        $mvnCommand = $null
        $mvnwPath = Join-Path $projectRoot "mvnw.cmd"
        $mvnwPathUnix = Join-Path $projectRoot "mvnw"
        
        if (Test-Path $mvnwPath) {
            $mvnCommand = $mvnwPath  # Use full path
        } elseif (Test-Path $mvnwPathUnix) {
            $mvnCommand = $mvnwPathUnix  # Use full path
        } else {
            # Try system Maven
            $mvnCheck = Get-Command mvn -ErrorAction SilentlyContinue
            if ($mvnCheck) {
                $mvnCommand = "mvn"
            } else {
                Write-Host "[ERROR] Maven not found! Please install Maven or use -SkipBuild flag." -ForegroundColor Red
                Write-Host "  Install Maven: https://maven.apache.org/download.cgi" -ForegroundColor Yellow
                Write-Host "  Or skip build: .\start-all.ps1 -SkipBuild" -ForegroundColor Yellow
                exit 1
            }
        }
        
        Write-Host "  Using: $mvnCommand" -ForegroundColor Gray
        & $mvnCommand clean install -DskipTests
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Build failed!" -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK] Build completed!" -ForegroundColor Green
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[4/6] Skipping build (using -SkipBuild)" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Start Spring Boot Services
$stepNumber = if ($SkipInfrastructure) { "[2/3]" } else { "[5/6]" }
Write-Host "$stepNumber Starting Spring Boot Services..." -ForegroundColor Yellow
Write-Host ""

# Function to start a service in a new window
function Start-ServiceInWindow {
    param(
        [string]$ServiceName,
        [string]$ServicePath,
        [int]$Port
    )
    
    Write-Host "  Starting $ServiceName on port $Port..." -ForegroundColor Gray
    
    $serviceDir = Join-Path $projectRoot $ServicePath
    if (-not (Test-Path $serviceDir)) {
        Write-Host "  [ERROR] Service directory not found: $serviceDir" -ForegroundColor Red
        return $false
    }
    
    # Create a PowerShell script to run the service
    $tempScript = Join-Path $env:TEMP "start-$ServiceName.ps1"
    
    # Determine Maven command (use full paths)
    $mvnCommand = "mvn"
    $mvnwPath = Join-Path $projectRoot "mvnw.cmd"
    $mvnwPathUnix = Join-Path $projectRoot "mvnw"
    
    if (Test-Path $mvnwPath) {
        $mvnCommand = "`"$mvnwPath`""  # Use full path with quotes
    } elseif (Test-Path $mvnwPathUnix) {
        $mvnCommand = "`"$mvnwPathUnix`""  # Use full path with quotes
    } else {
        # Try system Maven
        $mvnCheck = Get-Command mvn -ErrorAction SilentlyContinue
        if (-not $mvnCheck) {
            Write-Host "  [WARNING] Maven not found - service may fail to start" -ForegroundColor Yellow
        }
    }
    
    $scriptContent = @"
Set-Location '$serviceDir'
Write-Host 'Starting $ServiceName...' -ForegroundColor Cyan
& $mvnCommand spring-boot:run
"@
    $scriptContent | Out-File -FilePath $tempScript -Encoding UTF8
    
    # Start in new window
    Start-Process powershell -ArgumentList "-NoExit", "-File", "`"$tempScript`""
    
    # Wait a bit for service to start
    Start-Sleep -Seconds 3
    
    return $true
}

# Start services in order
$servicesStarted = $true

# API Gateway (Port 8080)
if (-not (Start-ServiceInWindow -ServiceName "API Gateway" -ServicePath "api-gateway" -Port 8080)) {
    $servicesStarted = $false
}
Start-Sleep -Seconds 5

# Create Service (Port 8081)
if (-not (Start-ServiceInWindow -ServiceName "Create Service" -ServicePath "create-service" -Port 8081)) {
    $servicesStarted = $false
}
Start-Sleep -Seconds 5

# Lookup Service (Port 8082)
if (-not (Start-ServiceInWindow -ServiceName "Lookup Service" -ServicePath "lookup-service" -Port 8082)) {
    $servicesStarted = $false
}
Start-Sleep -Seconds 5

# Stats Service (Port 8083)
if (-not (Start-ServiceInWindow -ServiceName "Stats Service" -ServicePath "stats-service" -Port 8083)) {
    $servicesStarted = $false
}

if (-not $servicesStarted) {
    Write-Host "[ERROR] Some services failed to start!" -ForegroundColor Red
    exit 1
}

Write-Host ""
$stepNumber = if ($SkipInfrastructure) { "[3/3]" } else { "[6/6]" }
Write-Host "$stepNumber Waiting for services to be ready..." -ForegroundColor Yellow
Write-Host "  Waiting 30 seconds for all services to start..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# Verify services are running
Write-Host ""
Write-Host "Verifying services..." -ForegroundColor Yellow

$services = @(
    @{Name="API Gateway"; Port=8080; Path="/actuator/health"},
    @{Name="Create Service"; Port=8081; Path="/actuator/health"},
    @{Name="Lookup Service"; Port=8082; Path="/actuator/health"},
    @{Name="Stats Service"; Port=8083; Path="/actuator/health"}
)

$allServicesReady = $true
foreach ($service in $services) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$($service.Port)$($service.Path)" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.status -eq "UP") {
            Write-Host "  [OK] $($service.Name) is running" -ForegroundColor Green
        } else {
            Write-Host "  [WARNING] $($service.Name) is not healthy" -ForegroundColor Yellow
            $allServicesReady = $false
        }
    } catch {
        Write-Host "  [WARNING] $($service.Name) is not responding yet" -ForegroundColor Yellow
        $allServicesReady = $false
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Startup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($allServicesReady) {
    Write-Host "[SUCCESS] All services are running!" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Some services may still be starting. Check the service windows." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Cyan
Write-Host "  API Gateway:    http://localhost:8080" -ForegroundColor White
Write-Host "  Create Service: http://localhost:8081" -ForegroundColor White
Write-Host "  Lookup Service: http://localhost:8082" -ForegroundColor White
Write-Host "  Stats Service:  http://localhost:8083" -ForegroundColor White
Write-Host ""
Write-Host "Health Checks:" -ForegroundColor Cyan
Write-Host "  API Gateway:    http://localhost:8080/actuator/health" -ForegroundColor White
Write-Host "  Create Service: http://localhost:8081/actuator/health" -ForegroundColor White
Write-Host "  Lookup Service: http://localhost:8082/actuator/health" -ForegroundColor White
Write-Host "  Stats Service:  http://localhost:8083/actuator/health" -ForegroundColor White
Write-Host ""
Write-Host "Infrastructure:" -ForegroundColor Cyan
Write-Host "  PostgreSQL Primary: localhost:5433" -ForegroundColor White
Write-Host "  PostgreSQL Replicas: localhost:5434,5435,5436" -ForegroundColor White
Write-Host "  Kafka Brokers: localhost:9092,9093,9094" -ForegroundColor White
Write-Host "  Redis Cluster: localhost:7001-7006" -ForegroundColor White
Write-Host ""
Write-Host "[INFO] Each service is running in a separate PowerShell window." -ForegroundColor Cyan
Write-Host "[INFO] To stop services, close the PowerShell windows or press Ctrl+C in each window." -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Kafka topics will be automatically created by the application on startup." -ForegroundColor Cyan
Write-Host "  Topics: url-click-events, url-deleted-events (6 partitions, replication factor 3)" -ForegroundColor Gray
Write-Host ""

