# PowerShell Script: Drop and Recreate Table as Partitioned
# Purpose: Drop existing regular table so schema.sql can create it as partitioned on next startup
# Usage: .\drop-and-recreate-table.ps1

param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5433,
    [string]$DbName = "shortify",
    [string]$DbUser = "postgres",
    [string]$DbPassword = "postgres"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Drop and Recreate Table" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is available and PostgreSQL container is running
$dockerPath = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerPath) {
    Write-Host "[ERROR] Docker command not found. Please install Docker." -ForegroundColor Red
    exit 1
}

# Check if PostgreSQL container is running
$containerName = "shortify-postgres-primary"
$containerExists = docker ps --filter "name=$containerName" --format "{{.Names}}" 2>$null
if (-not $containerExists) {
    Write-Host "[ERROR] PostgreSQL container '$containerName' is not running." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Connected to PostgreSQL container" -ForegroundColor Green
Write-Host ""

# Check current table status
Write-Host "[1/3] Checking current table status..." -ForegroundColor Yellow
$checkQuery = @"
SELECT 
    CASE 
        WHEN relkind = 'p' THEN 'partitioned'
        WHEN relkind = 'r' THEN 'regular'
        ELSE 'unknown'
    END as table_type,
    (SELECT COUNT(*) FROM url_mappings) as row_count
FROM pg_class
WHERE relname = 'url_mappings' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
"@

try {
    $checkResult = $checkQuery | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A -F "|" 2>&1
    $parts = $checkResult -split '\|'
    $tableType = $parts[0].Trim()
    $rowCount = $parts[1].Trim()
    
    Write-Host "   Table type: $tableType" -ForegroundColor White
    Write-Host "   Current row count: $rowCount" -ForegroundColor White
    
    if ($tableType -eq "partitioned") {
        Write-Host "[INFO] Table is already partitioned! Nothing to do." -ForegroundColor Green
        exit 0
    }
    
    if ([int]$rowCount -gt 0) {
        Write-Host "[WARNING] Table contains $rowCount rows!" -ForegroundColor Yellow
        Write-Host "  This will DELETE all data. Make sure you have a backup!" -ForegroundColor Red
        $confirm = Read-Host "  Type 'YES' to continue"
        if ($confirm -ne "YES") {
            Write-Host "[CANCELLED] Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    Write-Host ""
} catch {
    Write-Host "[ERROR] Failed to check table: $_" -ForegroundColor Red
    exit 1
}

# Drop the table
Write-Host "[2/3] Dropping existing table..." -ForegroundColor Yellow
$dropQuery = "DROP TABLE IF EXISTS url_mappings CASCADE;"

try {
    $dropResult = $dropQuery | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -q 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [OK] Table dropped successfully" -ForegroundColor Green
    } else {
        Write-Host "   [ERROR] Failed to drop table: $dropResult" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   [ERROR] Failed to drop table: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Inform user about next steps
Write-Host "[3/3] Next steps..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Table Dropped Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The table has been dropped. Now:" -ForegroundColor White
Write-Host ""
Write-Host "1. Restart the Create Service:" -ForegroundColor Yellow
Write-Host "   - Stop the Create Service (Ctrl+C in its window)" -ForegroundColor White
Write-Host "   - Start it again (or restart all services)" -ForegroundColor White
Write-Host ""
Write-Host "2. On startup, schema.sql will automatically:" -ForegroundColor Yellow
Write-Host "   - Create url_mappings as a PARTITIONED table" -ForegroundColor White
Write-Host "   - DatabasePartitionInitializer will create partitions" -ForegroundColor White
Write-Host ""
Write-Host "3. Verify partitions were created:" -ForegroundColor Yellow
Write-Host "   .\list-partitions.ps1" -ForegroundColor White
Write-Host ""

