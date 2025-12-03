# PowerShell Script: Insert 10K Records Randomly Across Next 12 Months
# Purpose: Insert test URL mappings with random dates across current month + next 11 months
# Usage: .\insert-random-12-months.ps1 [-Count 10000]

param(
    [int]$Count = 10000
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Insert $Count Records Across Next 12 Months" -ForegroundColor Cyan
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

$DbUser = "postgres"
$DbPassword = "postgres"
$DbName = "shortify"

Write-Host "[OK] Connected to PostgreSQL container" -ForegroundColor Green
Write-Host ""

# Generate unique short prefix for this run (max 2 chars to leave room for 8-digit number = 10 chars total)
# Use hash of timestamp to get 1-2 character prefix
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$hash = [System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($timestamp)) -replace "-", ""
$runPrefix = "R" + $hash.Substring(0, 1)  # R + 1 char = 2 chars, leaving 8 digits (fits 10 chars total)
Write-Host "Using prefix: $runPrefix (all codes will be 10 characters max)" -ForegroundColor Cyan
Write-Host ""

# Calculate date range: current month + next 11 months (12 months total)
$today = Get-Date
$startMonth = Get-Date -Year $today.Year -Month $today.Month -Day 1
$endMonth = $startMonth.AddMonths(12)

Write-Host "Date Range:" -ForegroundColor Cyan
Write-Host "  Start: $($startMonth.ToString('yyyy-MM-dd'))" -ForegroundColor White
Write-Host "  End:   $($endMonth.AddDays(-1).ToString('yyyy-MM-dd'))" -ForegroundColor White
Write-Host "  Total: 12 months" -ForegroundColor White
Write-Host ""

# Base URLs for variety
$baseUrls = @(
    "https://example.com/page",
    "https://test.com/article",
    "https://demo.com/product",
    "https://sample.com/blog",
    "https://mock.com/resource",
    "https://api.example.com/v1/data",
    "https://docs.example.com/guide",
    "https://blog.example.com/post"
)

Write-Host "Generating $Count records with random dates..." -ForegroundColor Yellow

# Generate random dates and build SQL statements
$sqlStatements = @()
$random = New-Object System.Random

# Track distribution for reporting
$monthDistribution = @{}
for ($m = 0; $m -lt 12; $m++) {
    $monthKey = $startMonth.AddMonths($m).ToString("yyyy-MM")
    $monthDistribution[$monthKey] = 0
}

for ($i = 1; $i -le $Count; $i++) {
    # Generate random date within the 12-month range
    $daysOffset = $random.Next(0, 365)  # Random day within 12 months
    $randomDate = $startMonth.AddDays($daysOffset)
    
    # Ensure we don't go beyond endMonth
    if ($randomDate -ge $endMonth) {
        $randomDate = $endMonth.AddDays(-1)
    }
    
    # Track month distribution
    $monthKey = $randomDate.ToString("yyyy-MM")
    if ($monthDistribution.ContainsKey($monthKey)) {
        $monthDistribution[$monthKey]++
    }
    
    # Generate test data
    $baseUrl = $baseUrls[$i % $baseUrls.Length]
    $originalUrl = "$baseUrl/$i?rand=$($random.Next(1000, 9999))&date=$($randomDate.ToString('yyyy-MM-dd'))"
    # Prefix (2 chars) + 8 digits = 10 chars total (max allowed)
    $shortCode = $runPrefix + $i.ToString("D8")
    
    # Random time within the day
    $randomHour = $random.Next(0, 24)
    $randomMinute = $random.Next(0, 60)
    $randomSecond = $random.Next(0, 60)
    $createdAt = $randomDate.AddHours($randomHour).AddMinutes($randomMinute).AddSeconds($randomSecond)
    $createdDate = $randomDate.ToString("yyyy-MM-dd")
    $expiresAt = $createdAt.AddYears(1).ToString("yyyy-MM-dd HH:mm:ss")
    $createdAtStr = $createdAt.ToString("yyyy-MM-dd HH:mm:ss")
    
    # Escape single quotes in URL
    $originalUrlEscaped = $originalUrl -replace "'", "''"
    
    $sqlStatements += "INSERT INTO url_mappings (original_url, short_url, created_at, created_date, expires_at, access_count, shard_id) VALUES ('$originalUrlEscaped', '$shortCode', '$createdAtStr'::TIMESTAMP, '$createdDate'::DATE, '$expiresAt'::TIMESTAMP, 0, 0);"
    
    if ($i % 1000 -eq 0) {
        Write-Host "  Generated $i/$Count records..." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Month Distribution:" -ForegroundColor Cyan
foreach ($month in ($monthDistribution.Keys | Sort-Object)) {
    $percentage = [math]::Round(($monthDistribution[$month] / $Count) * 100, 1)
    Write-Host "  $month : $($monthDistribution[$month]) records ($percentage%)" -ForegroundColor White
}
Write-Host ""

# Execute SQL statements in batches using temporary files for reliability
Write-Host "Inserting records into database..." -ForegroundColor Yellow
$batchSize = 1000  # Larger batches for better performance
$successCount = 0
$errorCount = 0
$totalBatches = [math]::Ceiling($sqlStatements.Length / $batchSize)
$tempDir = [System.IO.Path]::GetTempPath()
$tempFileBase = "insert_batch_"

for ($i = 0; $i -lt $sqlStatements.Length; $i += $batchSize) {
    $batch = $sqlStatements[$i..([math]::Min($i + $batchSize - 1, $sqlStatements.Length - 1))]
    $batchNum = [math]::Floor($i / $batchSize) + 1
    
    # Wrap batch in a transaction
    $batchSql = "BEGIN;`n" + ($batch -join "`n") + "`nCOMMIT;"
    
    # Write to temp file
    $tempFile = Join-Path $tempDir "$tempFileBase$batchNum.sql"
    try {
        $batchSql | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline
        
        # Copy file into container and execute
        docker cp $tempFile "${containerName}:/tmp/batch.sql" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $result = docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -f /tmp/batch.sql 2>&1
            $exitCode = $LASTEXITCODE
            
            # Clean up temp file in container
            docker exec $containerName rm -f /tmp/batch.sql | Out-Null
            
            # Check for errors
            if ($exitCode -ne 0 -or ($result -and $result -match "ERROR|error|ROLLBACK")) {
                $errorCount += $batch.Length
                Write-Host "  [ERROR] Batch $batchNum/$totalBatches failed" -ForegroundColor Red
                if ($result -and $batchNum -eq 1) {
                    # Show error for first batch only
                    $errorLines = ($result -split "`n")[0..9]
                    Write-Host "    $($errorLines -join "`n    ")" -ForegroundColor Red
                }
            } else {
                $successCount += $batch.Length
                if ($batchNum % 5 -eq 0 -or $batchNum -eq $totalBatches) {
                    Write-Host "  Batch $batchNum/$totalBatches ($successCount/$Count records)" -ForegroundColor Gray
                }
            }
        } else {
            $errorCount += $batch.Length
            Write-Host "  [ERROR] Batch $batchNum/$totalBatches - failed to copy file to container" -ForegroundColor Red
        }
        
        # Clean up local temp file
        Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
    } catch {
        $errorCount += $batch.Length
        Write-Host "  [ERROR] Batch $batchNum/$totalBatches exception: $_" -ForegroundColor Red
        Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Insertion Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Success: $successCount records" -ForegroundColor Green
if ($errorCount -gt 0) {
    Write-Host "  Errors: $errorCount records" -ForegroundColor Red
}
Write-Host ""

# Verify data distribution across partitions
Write-Host "Verifying partition distribution..." -ForegroundColor Yellow
$verifySql = @"
SELECT 
    tableoid::regclass as partition_name,
    COUNT(*) as row_count,
    MIN(created_date) as min_date,
    MAX(created_date) as max_date
FROM url_mappings
WHERE short_url LIKE '$runPrefix%'
GROUP BY tableoid::regclass
ORDER BY partition_name;
"@

try {
    $verifyResult = $verifySql | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A -F "|"
    
    if ($verifyResult) {
        Write-Host ""
        Write-Host "Partition Distribution:" -ForegroundColor Cyan
        $separator = "   " + ("-" * 70)
        Write-Host $separator -ForegroundColor Gray
        
        $header = "   {0,-40} {1,10} {2,12} {3,12}" -f "Partition Name", "Rows", "Min Date", "Max Date"
        Write-Host $header -ForegroundColor Cyan
        Write-Host $separator -ForegroundColor Gray
        
        $totalRows = 0
        foreach ($line in $verifyResult) {
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
        Write-Host "  [WARNING] No data found in partitions" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [ERROR] Failed to verify distribution: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  - Check detailed partition info: .\list-partitions.ps1" -ForegroundColor White
Write-Host "  - Verify data insertion: .\test-insert-and-verify.ps1" -ForegroundColor White
Write-Host ""

exit 0

