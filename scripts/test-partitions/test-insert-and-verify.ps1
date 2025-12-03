# PowerShell Script: Test Data Insertion and Verification
# Purpose: Insert test data and verify it's distributed across partitions correctly
# Usage: .\test-insert-and-verify.ps1 [-Count 50] [-ServiceUrl "http://localhost:8081"]

param(
    [int]$Count = 50,
    [string]$ServiceUrl = "http://localhost:8081"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Data Insertion and Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is available and PostgreSQL container is running
$dockerPath = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerPath) {
    Write-Host "[ERROR] Docker command not found. Please install Docker." -ForegroundColor Red
    exit 1
}

$containerName = "shortify-postgres-primary"
$containerExists = docker ps --filter "name=$containerName" --format "{{.Names}}" 2>$null
if (-not $containerExists) {
    Write-Host "[ERROR] PostgreSQL container '$containerName' is not running." -ForegroundColor Red
    exit 1
}

$DbUser = "postgres"
$DbPassword = "postgres"
$DbName = "shortify"

Write-Host "[OK] Connected to PostgreSQL container" -ForegroundColor Green
Write-Host ""

# Step 1: Verify partitions exist
Write-Host "[1/4] Verifying partitions exist..." -ForegroundColor Yellow
$partitionCheck = @"
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN relkind = 'p' THEN 'partitioned'
        WHEN relkind = 'r' THEN 'regular'
        ELSE 'unknown'
    END as table_type
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = t.schemaname)
WHERE schemaname = 'public' AND tablename = 'url_mappings';
"@

try {
    $tableInfo = $partitionCheck | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A -F "|"
    $parts = $tableInfo -split '\|'
    $tableType = $parts[2].Trim()
    
    if ($tableType -eq "partitioned") {
        Write-Host "   [OK] Table is partitioned" -ForegroundColor Green
    } else {
        Write-Host "   [WARNING] Table is NOT partitioned ($tableType)" -ForegroundColor Yellow
        Write-Host "   Please restart the Create Service to create partitions" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERROR] Failed to check table: $_" -ForegroundColor Red
    exit 1
}

# Count partitions
$partitionCountQuery = @"
SELECT COUNT(*) 
FROM pg_inherits 
WHERE inhparent = (SELECT oid FROM pg_class WHERE relname = 'url_mappings' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'));
"@

try {
    $partitionCount = $partitionCountQuery | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A
    $partitionCount = $partitionCount.Trim()
    Write-Host "   [INFO] Found $partitionCount child partitions" -ForegroundColor White
} catch {
    Write-Host "   [WARNING] Could not count partitions" -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Insert data via REST API
Write-Host "[2/4] Inserting $Count URLs via REST API..." -ForegroundColor Yellow
$testUrls = @(
    "https://example.com/page1",
    "https://example.com/page2",
    "https://google.com/search",
    "https://github.com/repo",
    "https://stackoverflow.com/question"
)

$successCount = 0
$failCount = 0

for ($i = 1; $i -le $Count; $i++) {
    $randomUrl = $testUrls[$i % $testUrls.Length] + "?id=$i&timestamp=$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    $body = @{
        originalUrl = $randomUrl
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$ServiceUrl/api/v1/create/shorten" `
            -Method Post `
            -ContentType "application/json" `
            -Body $body `
            -ErrorAction Stop
        
        if ($response.success) {
            $successCount++
            if ($i % 10 -eq 0) {
                Write-Host "   Inserted $i/$Count URLs..." -ForegroundColor Gray
            }
        } else {
            $failCount++
        }
    } catch {
        $failCount++
        if ($i -le 5) {
            Write-Host "   [WARNING] Failed to insert URL $i : $_" -ForegroundColor Yellow
        }
    }
    
    # Small delay to avoid overwhelming the service
    Start-Sleep -Milliseconds 50
}

Write-Host "   [OK] Inserted $successCount URLs successfully" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "   [WARNING] Failed to insert $failCount URLs" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Verify data distribution across partitions
Write-Host "[3/4] Verifying data distribution across partitions..." -ForegroundColor Yellow
$distributionQuery = @"
SELECT 
    tableoid::regclass as partition_name,
    COUNT(*) as row_count,
    MIN(created_date) as min_date,
    MAX(created_date) as max_date
FROM url_mappings
GROUP BY tableoid::regclass
ORDER BY partition_name;
"@

try {
    $distribution = $distributionQuery | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A -F "|"
    
    if ($distribution) {
        Write-Host ""
        Write-Host "   Partition Distribution:" -ForegroundColor White
        $separator = "   " + ("-" * 70)
        Write-Host $separator -ForegroundColor Gray
        
        $header = "   {0,-40} {1,10} {2,12} {3,12}" -f "Partition Name", "Rows", "Min Date", "Max Date"
        Write-Host $header -ForegroundColor Cyan
        Write-Host $separator -ForegroundColor Gray
        
        $totalRows = 0
        foreach ($line in $distribution) {
            if ($line.Trim()) {
                $parts = $line -split '\|'
                $partitionName = $parts[0].Trim()
                $rowCount = [int]$parts[1].Trim()
                $minDate = $parts[2].Trim()
                $maxDate = $parts[3].Trim()
                $totalRows += $rowCount
                
                $row = "   {0,-40} {1,10} {2,12} {3,12}" -f $partitionName, $rowCount, $minDate, $maxDate
                Write-Host $row -ForegroundColor White
            }
        }
        
        Write-Host $separator -ForegroundColor Gray
        $totalRow = "   {0,-40} {1,10}" -f "TOTAL", $totalRows
        Write-Host $totalRow -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "   [WARNING] No data found in partitions" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERROR] Failed to check distribution: $_" -ForegroundColor Red
}

Write-Host ""

# Step 4: Show sample data
Write-Host "[4/4] Showing sample data..." -ForegroundColor Yellow
$sampleQuery = @"
SELECT 
    id,
    short_url,
    LEFT(original_url, 50) as original_url_preview,
    created_date,
    tableoid::regclass as partition_name
FROM url_mappings
ORDER BY id DESC
LIMIT 5;
"@

try {
    $samples = $sampleQuery | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A -F "|"
    
    if ($samples) {
        Write-Host ""
        Write-Host "   Sample Records:" -ForegroundColor White
        Write-Host "   " + ("-" * 100) -ForegroundColor Gray
        
        foreach ($line in $samples) {
            if ($line.Trim()) {
                $parts = $line -split '\|'
                $id = $parts[0].Trim()
                $shortUrl = $parts[1].Trim()
                $originalUrl = $parts[2].Trim()
                $createdDate = $parts[3].Trim()
                $partitionName = $parts[4].Trim()
                
                Write-Host "   ID: $id | Short: $shortUrl | Date: $createdDate | Partition: $partitionName" -ForegroundColor White
                Write-Host "      URL: $originalUrl..." -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
} catch {
    Write-Host "   [WARNING] Could not retrieve sample data: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Check partition distribution: .\list-partitions.ps1" -ForegroundColor White
Write-Host "  2. Insert more test data: .\insert-test-data-direct.ps1 -Count 1000" -ForegroundColor White
Write-Host "  3. Test partition management: .\test-partition-management.ps1" -ForegroundColor White
Write-Host ""

