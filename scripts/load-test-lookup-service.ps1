# Load Test Script for Lookup Service (via API Gateway)
# Reads all URLs from the lookup service through the API Gateway 5 times
# Run: .\load-test-lookup-service.ps1
#
# Performance Optimizations:
# - Increased default concurrency from 20 to 100 parallel requests
# - Reduced timeout from 10s to 5s for faster failure detection
# - Enabled KeepAlive for HTTP connection reuse
# - Reduced sleep time from 10ms to 1ms in result collection loop
# - Less frequent progress updates (every 10% instead of 5%)
# - Pre-processed URL list (trimmed once instead of per iteration)

param(
    [int]$Iterations = 5,
    [string]$ApiGatewayUrl = "http://localhost:8080",
    [string]$ShortUrlsFile = "short-urls.txt",
    [int]$Concurrency = 100  # Number of parallel requests (increased from 20 for better performance)
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lookup Service Load Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  API Gateway URL: $ApiGatewayUrl" -ForegroundColor White
Write-Host "  Iterations: $Iterations" -ForegroundColor White
Write-Host "  Concurrency: $Concurrency parallel requests" -ForegroundColor White
Write-Host "  Short URLs File: $ShortUrlsFile`n" -ForegroundColor White

# Check if API Gateway and lookup service are running
Write-Host "[1/5] Checking API Gateway and lookup service health..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-WebRequest -Uri "$ApiGatewayUrl/health/lookup" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($healthResponse.StatusCode -eq 200) {
        Write-Host "  API Gateway and lookup service are healthy!`n" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: API Gateway returned status code $($healthResponse.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: API Gateway is not reachable at $ApiGatewayUrl" -ForegroundColor Red
    Write-Host "  Please make sure:" -ForegroundColor Yellow
    Write-Host "    1. API Gateway is running on port 8080" -ForegroundColor Yellow
    Write-Host "    2. Lookup service is running on port 8082`n" -ForegroundColor Yellow
    exit 1
}

# Load short URLs from file
Write-Host "[2/5] Loading short URLs from file..." -ForegroundColor Yellow
if (-not (Test-Path $ShortUrlsFile)) {
    Write-Host "  ERROR: File '$ShortUrlsFile' not found!" -ForegroundColor Red
    Write-Host "  Please run load-test-create-service.ps1 first to generate short URLs.`n" -ForegroundColor Yellow
    exit 1
}

# Load and pre-process URLs once (more efficient)
$shortUrls = Get-Content -Path $ShortUrlsFile -ErrorAction Stop | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
$urlCount = $shortUrls.Count

if ($urlCount -eq 0) {
    Write-Host "  ERROR: No short URLs found in file '$ShortUrlsFile'!" -ForegroundColor Red
    Write-Host "  Please run load-test-create-service.ps1 first to generate short URLs.`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "  Loaded $urlCount short URLs from file`n" -ForegroundColor Green

# Perform lookups
Write-Host "[3/5] Performing lookups ($Iterations iterations)..." -ForegroundColor Yellow

$totalLookups = 0
$totalSuccess = 0
$totalNotFound = 0
$totalErrors = 0
$startTime = Get-Date

for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
    Write-Host "`n  Iteration $iteration/$Iterations..." -ForegroundColor Cyan
    $iterationStartTime = Get-Date
    $iterationSuccess = 0
    $iterationNotFound = 0
    $iterationErrors = 0
    
    # Progress tracking (less frequent updates = less overhead)
    $progressInterval = [math]::Max(1, [math]::Floor($urlCount / 10))  # Update every 10% instead of 5%
    
    # Pre-process URLs once (already trimmed, just create objects)
    $urlsToProcess = 0..($urlCount - 1) | ForEach-Object { 
        @{
            Index = $_
            ShortCode = $shortUrls[$_]
        }
    }
    
    # Use RunspacePool for efficient parallel processing (PowerShell 5.1 compatible)
    $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Concurrency)
    $runspacePool.Open()
    $runspaces = New-Object System.Collections.ArrayList
    $lockObject = [System.Object]::new()
    
    # Process URLs in parallel using RunspacePool
    foreach ($urlData in $urlsToProcess) {
        $powershell = [PowerShell]::Create()
        $powershell.RunspacePool = $runspacePool
        
        # Create optimized scriptblock using HttpWebRequest (optimized for redirect checking)
        $scriptBlock = {
            param($shortCode, $apiGatewayUrl)
            
            $result = @{
                Success = $false
                NotFound = $false
                Error = $false
                StatusCode = $null
                ErrorMessage = $null
                ShortCode = $shortCode
            }
            
            try {
                # Optimized HttpWebRequest (faster than Invoke-WebRequest for redirect checking)
                $request = [System.Net.HttpWebRequest]::Create("$apiGatewayUrl/$shortCode")
                $request.Method = "GET"
                $request.Timeout = 5000  # Reduced from 10000ms to 5000ms
                $request.ReadWriteTimeout = 5000
                $request.AllowAutoRedirect = $false
                $request.KeepAlive = $true  # Enable connection reuse
                
                try {
                    $response = $request.GetResponse()
                    $result.StatusCode = [int]$response.StatusCode
                    $response.Close()
                } catch [System.Net.WebException] {
                    $webException = $_.Exception
                    if ($webException.Response) {
                        $result.StatusCode = [int]$webException.Response.StatusCode
                        $webException.Response.Close()
                    } else {
                        $result.StatusCode = $null
                        $result.ErrorMessage = $webException.Message
                    }
                }
                
                # Determine result type
                if ($result.StatusCode -eq 302) {
                    $result.Success = $true
                } elseif ($result.StatusCode -eq 404) {
                    $result.NotFound = $true
                } elseif ($null -ne $result.StatusCode) {
                    $result.NotFound = $true
                } else {
                    $result.Error = $true
                }
            } catch {
                $result.Error = $true
                $result.ErrorMessage = $_.Exception.Message
            }
            
            return $result
        }
        
        [void]$powershell.AddScript($scriptBlock.ToString())
        [void]$powershell.AddArgument($urlData.ShortCode)
        [void]$powershell.AddArgument($ApiGatewayUrl)
        
        $handle = $powershell.BeginInvoke()
        [void]$runspaces.Add(@{
            PowerShell = $powershell
            Handle = $handle
            ShortCode = $urlData.ShortCode
        })
    }
    
    # Collect results as they complete
    $processedCount = 0
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
                        $iterationSuccess++
                        $totalSuccess++
                    } finally {
                        [System.Threading.Monitor]::Exit($lockObject)
                    }
                } elseif ($result.NotFound) {
                    [System.Threading.Monitor]::Enter($lockObject)
                    try {
                        $iterationNotFound++
                        $totalNotFound++
                    } finally {
                        [System.Threading.Monitor]::Exit($lockObject)
                    }
                } elseif ($result.Error) {
                    [System.Threading.Monitor]::Enter($lockObject)
                    try {
                        $iterationErrors++
                        $totalErrors++
                        # Only log first few errors
                        if ($totalErrors -le 5) {
                            Write-Host "    Error for '$($result.ShortCode)': $($result.ErrorMessage)" -ForegroundColor Red
                        }
                    } finally {
                        [System.Threading.Monitor]::Exit($lockObject)
                    }
                }
                
                $totalLookups++
                $processedCount++
                
                # Progress update (less frequent to reduce overhead)
                if ($processedCount % $progressInterval -eq 0 -or $processedCount -eq $urlCount) {
                    $percentComplete = [math]::Round(($processedCount / $urlCount) * 100, 1)
                    $elapsed = (Get-Date) - $iterationStartTime
                    $rate = $processedCount / $elapsed.TotalSeconds
                    Write-Host "    Progress: $percentComplete% ($processedCount/$urlCount) | Success: $iterationSuccess | Not Found: $iterationNotFound | Errors: $iterationErrors | Rate: $([math]::Round($rate, 1)) req/s" -ForegroundColor Gray
                }
            } catch {
                [System.Threading.Monitor]::Enter($lockObject)
                try {
                    $iterationErrors++
                    $totalErrors++
                    if ($totalErrors -le 5) {
                        Write-Host "    Error processing '$($runspace.ShortCode)': $($_.Exception.Message)" -ForegroundColor Red
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
            Start-Sleep -Milliseconds 1  # Reduced from 10ms to 1ms for faster processing
        }
    }
    
    # Cleanup
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    $iterationTime = (Get-Date) - $iterationStartTime
    $iterationRate = $urlCount / $iterationTime.TotalSeconds
    
    Write-Host "    Iteration $iteration complete: $([math]::Round($iterationTime.TotalSeconds, 2))s | $([math]::Round($iterationRate, 1)) req/s | Success: $iterationSuccess | Not Found: $iterationNotFound | Errors: $iterationErrors" -ForegroundColor Green
}

# Calculate statistics
Write-Host "`n[4/5] Calculating statistics..." -ForegroundColor Yellow
$endTime = Get-Date
$totalTime = $endTime - $startTime
$avgRate = $totalLookups / $totalTime.TotalSeconds
$successRate = if ($totalLookups -gt 0) { ($totalSuccess / $totalLookups) * 100 } else { 0 }

Write-Host "[5/5] Test Results" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Iterations:     $Iterations" -ForegroundColor White
Write-Host "URLs per Iteration:   $urlCount" -ForegroundColor White
Write-Host "Total Lookups:        $totalLookups" -ForegroundColor White
Write-Host "Successful:           $totalSuccess" -ForegroundColor Green
Write-Host "Not Found:            $totalNotFound" -ForegroundColor Yellow
Write-Host "Errors:               $totalErrors" -ForegroundColor $(if ($totalErrors -gt 0) { "Red" } else { "Green" })
Write-Host "Success Rate:         $([math]::Round($successRate, 2))%" -ForegroundColor White
Write-Host "Total Time:           $([math]::Round($totalTime.TotalSeconds, 2)) seconds" -ForegroundColor White
Write-Host "Average Rate:         $([math]::Round($avgRate, 2)) requests/second" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

if ($totalErrors -eq 0 -and $totalSuccess -gt 0) {
    Write-Host "[SUCCESS] All lookups completed successfully!`n" -ForegroundColor Green
} elseif ($totalErrors -gt 0) {
    Write-Host "[WARNING] Some lookups failed. Check the output above for details.`n" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] No successful lookups. Make sure URLs exist in the database.`n" -ForegroundColor Yellow
}