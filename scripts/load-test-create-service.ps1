# Load Test Script for Create Service (via API Gateway)
# Sends 10,000 URLs to the create service through the API Gateway
# Run: .\load-test-create-service.ps1

param(
    [int]$UrlCount = 1000000000,
    [string]$CreateServiceUrl = "http://localhost:8080",
    [string]$OutputFile = "short-urls.txt",
    [int]$Concurrency = 20  # Number of parallel requests
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Create Service Load Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  API Gateway URL: $CreateServiceUrl" -ForegroundColor White
Write-Host "  Number of URLs: $UrlCount" -ForegroundColor White
Write-Host "  Concurrency: $Concurrency parallel requests" -ForegroundColor White
Write-Host "  Output File: $OutputFile`n" -ForegroundColor White

# Check if API Gateway and create service are running
Write-Host "[1/4] Checking API Gateway and create service health..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-WebRequest -Uri "$CreateServiceUrl/health/create" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($healthResponse.StatusCode -eq 200) {
        Write-Host "  Create service is healthy!`n" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Create service returned status code $($healthResponse.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: Create service is not reachable at $CreateServiceUrl" -ForegroundColor Red
    Write-Host "  Please make sure the API Gateway is running on port 8080`n" -ForegroundColor Yellow
    exit 1
}

# Generate URLs and send requests
Write-Host "[2/4] Generating and sending $UrlCount URLs in batches of 1000..." -ForegroundColor Yellow

$shortUrls = @()
$successCount = 0
$failureCount = 0
$startTime = Get-Date
$batchSize = 1000
$totalBatches = [math]::Ceiling($UrlCount / $batchSize)

$baseUrls = @(
    "https://www.example.com",
    "https://www.google.com",
    "https://www.github.com",
    "https://www.stackoverflow.com",
    "https://www.reddit.com",
    "https://www.youtube.com",
    "https://www.amazon.com",
    "https://www.microsoft.com",
    "https://www.apple.com",
    "https://www.netflix.com"
)

# Progress tracking
$progressInterval = [math]::Max(1, [math]::Floor($batchSize / 20))  # Update every 5% of batch

# Lock object for thread-safe operations
$lockObject = [System.Object]::new()

# Scriptblock for processing URLs
$scriptBlock = {
    param($originalUrl, $index, $createServiceUrl)
    
    $result = @{
        Index = $index
        Success = $false
        ShortCode = $null
        Error = $null
    }
    
    try {
        # Create request body
        $requestBody = @{
            originalUrl = $originalUrl
            baseUrl = "https://tiny.url"
        } | ConvertTo-Json
        
        # Send POST request
        $response = Invoke-RestMethod -Uri "$createServiceUrl/api/v1/create/shorten" `
            -Method Post `
            -ContentType "application/json" `
            -Body $requestBody `
            -TimeoutSec 30 `
            -ErrorAction Stop
        
        if ($response.success -eq $true -and $response.shortCode) {
            $result.Success = $true
            $result.ShortCode = $response.shortCode
        } else {
            $result.Error = $response.errorCode
        }
    } catch {
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

# Process URLs in batches of 1000
for ($batchNumber = 1; $batchNumber -le $totalBatches; $batchNumber++) {
    $batchStart = ($batchNumber - 1) * $batchSize + 1
    $batchEnd = [math]::Min($batchNumber * $batchSize, $UrlCount)
    $currentBatchSize = $batchEnd - $batchStart + 1
    
    Write-Host "  Processing batch $batchNumber/$totalBatches (URLs $batchStart-$batchEnd)..." -ForegroundColor Cyan
    
    # Prepare URLs for this batch
    $urlsToProcess = $batchStart..$batchEnd | ForEach-Object {
        $randomBaseUrl = $baseUrls | Get-Random
        $timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        $randomParam = Get-Random -Minimum 1000 -Maximum 999999
        @{
            Index = $_
            OriginalUrl = "$randomBaseUrl/page?id=$timestamp&ref=$randomParam&index=$_"
        }
    }
    
    # Use RunspacePool for efficient parallel processing within batch
    $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Concurrency)
    $runspacePool.Open()
    $runspaces = New-Object System.Collections.ArrayList
    
    # Process URLs in parallel within this batch
    foreach ($urlData in $urlsToProcess) {
        $powershell = [PowerShell]::Create()
        $powershell.RunspacePool = $runspacePool
        
        [void]$powershell.AddScript($scriptBlock.ToString())
        [void]$powershell.AddArgument($urlData.OriginalUrl)
        [void]$powershell.AddArgument($urlData.Index)
        [void]$powershell.AddArgument($CreateServiceUrl)
        
        $handle = $powershell.BeginInvoke()
        [void]$runspaces.Add(@{
            PowerShell = $powershell
            Handle = $handle
            Index = $urlData.Index
        })
    }
    
    # Collect results as they complete for this batch
    $batchProcessedCount = 0
    while ($runspaces.Count -gt 0) {
        $completedIndices = @()
        
        for ($i = $runspaces.Count - 1; $i -ge 0; $i--) {
            $runspace = $runspaces[$i]
            
            if ($runspace.Handle.IsCompleted) {
                $completedIndices += $i
            }
        }
        
        foreach ($i in $completedIndices) {
            $runspace = $runspaces[$i]
            
            try {
                $result = $runspace.PowerShell.EndInvoke($runspace.Handle)
                
                if ($result.Success) {
                    [System.Threading.Monitor]::Enter($lockObject)
                    try {
                        $shortUrls += $result.ShortCode
                        $successCount++
                        
                        # Save to file incrementally (every 100 URLs)
                        if ($successCount % 100 -eq 0) {
                            $shortUrls | Out-File -FilePath $OutputFile -Encoding utf8
                        }
                    } finally {
                        [System.Threading.Monitor]::Exit($lockObject)
                    }
                } else {
                    [System.Threading.Monitor]::Enter($lockObject)
                    try {
                        $failureCount++
                        if ($failureCount -le 5) {
                            Write-Host "    Failed to create URL #$($result.Index) : $($result.Error)" -ForegroundColor Red
                        }
                    } finally {
                        [System.Threading.Monitor]::Exit($lockObject)
                    }
                }
                
                $batchProcessedCount++
                $processedCount = ($batchNumber - 1) * $batchSize + $batchProcessedCount
                
                # Progress update within batch
                if ($batchProcessedCount % $progressInterval -eq 0 -or $batchProcessedCount -eq $currentBatchSize) {
                    $percentComplete = [math]::Round(($processedCount / $UrlCount) * 100, 1)
                    $elapsed = (Get-Date) - $startTime
                    $rate = $processedCount / $elapsed.TotalSeconds
                    $remaining = ($UrlCount - $processedCount) / $rate
                    Write-Host "    Batch progress: $batchProcessedCount/$currentBatchSize | Overall: $percentComplete% ($processedCount/$UrlCount) | Success: $successCount | Failures: $failureCount | Rate: $([math]::Round($rate, 1)) req/s | ETA: $([math]::Round($remaining, 0))s" -ForegroundColor White
                }
            } catch {
                [System.Threading.Monitor]::Enter($lockObject)
                try {
                    $failureCount++
                    if ($failureCount -le 5) {
                        Write-Host "    Error processing URL #$($runspace.Index) : $($_.Exception.Message)" -ForegroundColor Red
                    }
                } finally {
                    [System.Threading.Monitor]::Exit($lockObject)
                }
            } finally {
                $runspace.PowerShell.Dispose()
                [void]$runspaces.RemoveAt($i)
            }
        }
        
        if ($runspaces.Count -gt 0) {
            Start-Sleep -Milliseconds 10
        }
    }
    
    # Cleanup runspace pool for this batch
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    Write-Host "  Batch $batchNumber completed: $batchProcessedCount/$currentBatchSize URLs processed`n" -ForegroundColor Green
}

# Save final list of short URLs
Write-Host "`n[3/4] Saving short URLs to file..." -ForegroundColor Yellow
$shortUrls | Out-File -FilePath $OutputFile -Encoding utf8
Write-Host "  Saved $($shortUrls.Count) short URLs to $OutputFile`n" -ForegroundColor Green

# Calculate statistics
$endTime = Get-Date
$totalTime = $endTime - $startTime
$avgRate = $UrlCount / $totalTime.TotalSeconds

Write-Host "[4/4] Test Results" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total URLs Sent:     $UrlCount" -ForegroundColor White
Write-Host "Successful:          $successCount" -ForegroundColor Green
Write-Host "Failed:               $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Green" })
Write-Host "Success Rate:         $([math]::Round(($successCount / $UrlCount) * 100, 2))%" -ForegroundColor White
Write-Host "Total Time:           $([math]::Round($totalTime.TotalSeconds, 2)) seconds" -ForegroundColor White
Write-Host "Average Rate:         $([math]::Round($avgRate, 2)) requests/second" -ForegroundColor White
Write-Host "Short URLs Saved:     $($shortUrls.Count) to $OutputFile" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

if ($successCount -eq $UrlCount) {
    Write-Host "[SUCCESS] All URLs created successfully!`n" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Some URLs failed to create. Check the output above for details.`n" -ForegroundColor Yellow
}