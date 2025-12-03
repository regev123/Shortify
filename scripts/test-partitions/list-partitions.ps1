# PowerShell Script: List All Partitions
# Purpose: Query PostgreSQL to show all partitions of url_mappings table
# Usage: .\list-partitions.ps1 [-DbHost "localhost"] [-DbPort 5433] [-DbName "shortify"] [-DbUser "postgres"] [-DbPassword "postgres"]

param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5433,
    [string]$DbName = "shortify",
    [string]$DbUser = "postgres",
    [string]$DbPassword = "postgres"
)

Write-Host "=== List All Partitions ===" -ForegroundColor Cyan
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
    Write-Host "  Please start PostgreSQL first using: scripts\Database\start-postgresql-with-replication.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Connected to PostgreSQL container" -ForegroundColor Green
Write-Host ""

# SQL query to list all partitions
$sqlQuery = @"
SELECT 
    t.schemaname,
    t.tablename as partition_name,
    pg_size_pretty(pg_total_relation_size(t.schemaname||'.'||t.tablename)) as size,
    COALESCE(s.n_live_tup, 0) as row_count
FROM pg_tables t
LEFT JOIN pg_stat_user_tables s ON s.schemaname = t.schemaname AND s.relname = t.tablename
WHERE t.schemaname = 'public' 
    AND t.tablename LIKE 'url_mappings%'
ORDER BY 
    CASE 
        WHEN t.tablename = 'url_mappings' THEN 0
        WHEN t.tablename LIKE 'url_mappings_hot%' THEN 1
        WHEN t.tablename LIKE 'url_mappings_%' THEN 2
        ELSE 3
    END,
    t.tablename;
"@

# First check if table is partitioned
$checkPartitionedQuery = @"
SELECT 
    CASE 
        WHEN relkind = 'p' THEN 'YES'
        WHEN relkind = 'r' THEN 'NO'
        ELSE 'UNKNOWN'
    END as is_partitioned
FROM pg_class
WHERE relname = 'url_mappings' 
  AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
"@

try {
    $isPartitioned = $checkPartitionedQuery | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A 2>&1
    $isPartitioned = $isPartitioned.Trim()
    
    if ($isPartitioned -eq "NO") {
        Write-Host "[WARNING] Table 'url_mappings' is NOT partitioned!" -ForegroundColor Yellow
        Write-Host "  Partitions will be created automatically on next server startup." -ForegroundColor White
        Write-Host ""
    }
} catch {
    Write-Host "[WARNING] Could not check if table is partitioned: $_" -ForegroundColor Yellow
}

Write-Host "Partition List:" -ForegroundColor Yellow
Write-Host ""

try {
    $result = $sqlQuery | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A -F "|" 2>&1
    
    if ($result -and $result -notmatch "ERROR") {
        $hasPartitions = $false
        Write-Host "Schema Name | Partition Name | Size | Row Count" -ForegroundColor Cyan
        Write-Host "------------|----------------|------|----------" -ForegroundColor Gray
        $result | ForEach-Object {
            $parts = $_ -split '\|'
            if ($parts.Length -ge 4) {
                $schema = $parts[0].Trim()
                $table = $parts[1].Trim()
                $size = $parts[2].Trim()
                $rows = $parts[3].Trim()
                
                if ($table -eq "url_mappings") {
                    Write-Host "$schema | $table (PARENT) | $size | $rows" -ForegroundColor White
                } elseif ($table -like "url_mappings_*") {
                    $hasPartitions = $true
                    Write-Host "$schema | $table | $size | $rows" -ForegroundColor Green
                } elseif ($table -like "url_mappings_hot*") {
                    Write-Host "$schema | $table (HOT) | $size | $rows" -ForegroundColor Cyan
                }
            }
        }
        
        if (-not $hasPartitions -and $isPartitioned -eq "YES") {
            Write-Host ""
            Write-Host "[INFO] Table is partitioned but no partitions found yet." -ForegroundColor Yellow
            Write-Host "  Partitions should be created automatically on server startup." -ForegroundColor White
            Write-Host "  Check Create Service logs for 'DatabasePartitionInitializer' messages." -ForegroundColor White
        }
    } else {
        Write-Host "[INFO] No partitions found." -ForegroundColor Yellow
        if ($isPartitioned -eq "YES") {
            Write-Host "  Partitions should be created automatically on server startup." -ForegroundColor White
        }
    }
} catch {
    Write-Host "[ERROR] Failed to query partitions: $_" -ForegroundColor Red
}

Write-Host ""

# Query to show partition details with date ranges
$detailQuery = @"
SELECT 
    c.relname as partition_name,
    pg_get_expr(c.relpartbound, c.oid) as partition_bound,
    pg_size_pretty(pg_total_relation_size('public.'||c.relname)) as size,
    COALESCE(s.n_live_tup, 0) as row_count
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
LEFT JOIN pg_stat_user_tables s ON s.relname = c.relname
WHERE i.inhparent = (
    SELECT oid FROM pg_class 
    WHERE relname = 'url_mappings' 
    AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
)
ORDER BY c.relname;
"@

Write-Host "Partition Details (with date ranges):" -ForegroundColor Yellow
Write-Host ""

try {
    $detailResult = $detailQuery | docker exec -i -e PGPASSWORD=$DbPassword $containerName psql -h localhost -U $DbUser -d $DbName -t -A -F "|" 2>&1
    
    if ($detailResult -and $detailResult -notmatch "ERROR" -and $detailResult.Trim() -ne "") {
        Write-Host "Partition Name | Bound Expression | Size | Row Count" -ForegroundColor Cyan
        Write-Host "---------------|------------------|------|----------" -ForegroundColor Gray
        $detailResult | ForEach-Object {
            if ($_ -and $_ -notmatch "ERROR") {
                $parts = $_ -split '\|'
                if ($parts.Length -ge 4) {
                    $table = $parts[0].Trim()
                    $expr = $parts[1].Trim()
                    $size = $parts[2].Trim()
                    $rows = $parts[3].Trim()
                    Write-Host "$table | $expr | $size | $rows" -ForegroundColor White
                }
            }
        }
    } else {
        Write-Host "  No partition details available (partitions may not exist yet)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Could not retrieve partition details: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Query Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: In pgAdmin 4, partitions appear under the parent table." -ForegroundColor Yellow
Write-Host "  Expand 'url_mappings' table -> Look for 'Partitions' or 'Child Tables' section" -ForegroundColor White
Write-Host ""

