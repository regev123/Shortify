# ================================================
# Stop and Clean Up Shortify Services in Kubernetes
# ================================================

Write-Host '================================================' -ForegroundColor Cyan
Write-Host 'Stopping Shortify Services in Kubernetes' -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ''

# Check prerequisites
Write-Host 'Checking prerequisites...' -ForegroundColor Yellow

# Check if kubectl is available
try {
    kubectl version --client | Out-Null
    Write-Host '[OK] kubectl is available' -ForegroundColor Green
} catch {
    Write-Host '[ERROR] kubectl is not installed or not in PATH' -ForegroundColor Red
    exit 1
}

# Check if Kubernetes cluster is accessible
try {
    kubectl cluster-info | Out-Null
    Write-Host '[OK] Kubernetes cluster is accessible' -ForegroundColor Green
} catch {
    Write-Host '[ERROR] Cannot connect to Kubernetes cluster' -ForegroundColor Red
    Write-Host 'Please ensure Docker Desktop is running and Kubernetes is enabled' -ForegroundColor Yellow
    exit 1
}

Write-Host ''

# Change to k8s directory (parent of scripts directory)
$k8sDir = Split-Path -Parent $PSScriptRoot
Push-Location $k8sDir

# Step 1: Delete application services
Write-Host 'Step 1: Deleting application services...' -ForegroundColor Yellow

Write-Host '  - API Gateway...' -ForegroundColor Gray
kubectl delete -f services/api-gateway-deployment.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f services/api-gateway-hpa.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - Create Service...' -ForegroundColor Gray
kubectl delete -f services/create-service-deployment.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - Lookup Service...' -ForegroundColor Gray
kubectl delete -f services/lookup-service-deployment.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f services/lookup-service-hpa.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - Stats Service...' -ForegroundColor Gray
kubectl delete -f services/stats-service-deployment.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - Ingress...' -ForegroundColor Gray
kubectl delete -f config/ingress.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '[OK] Application services deleted' -ForegroundColor Green
Write-Host ''

# Step 2: Delete infrastructure services
Write-Host 'Step 2: Deleting infrastructure services...' -ForegroundColor Yellow

Write-Host '  - Kafka Brokers...' -ForegroundColor Gray
kubectl delete -f infrastructure/kafka/kafka-broker-1.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/kafka/kafka-broker-2.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/kafka/kafka-broker-3.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/kafka/kafka-cluster-service.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - Zookeeper...' -ForegroundColor Gray
kubectl delete -f infrastructure/kafka/kafka-zookeeper.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - Redis Cluster...' -ForegroundColor Gray
kubectl delete -f infrastructure/redis/redis-cluster-node-1.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/redis/redis-cluster-node-2.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/redis/redis-cluster-node-3.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/redis/redis-cluster-node-4.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/redis/redis-cluster-node-5.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/redis/redis-cluster-node-6.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/redis/redis-cluster-service.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/redis/redis-cluster-init-job.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - PostgreSQL Replicas...' -ForegroundColor Gray
kubectl delete -f infrastructure/postgresql/postgresql-replica-1.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/postgresql/postgresql-replica-2.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/postgresql/postgresql-replica-3.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null
kubectl delete -f infrastructure/postgresql/postgresql-replicas-service.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - PostgreSQL Stats...' -ForegroundColor Gray
kubectl delete -f infrastructure/postgresql/postgresql-stats.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - PostgreSQL Primary...' -ForegroundColor Gray
kubectl delete -f infrastructure/postgresql/postgresql-primary.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '[OK] Infrastructure services deleted' -ForegroundColor Green
Write-Host ''

# Step 3: Delete ConfigMap and Secrets
Write-Host 'Step 3: Deleting configuration...' -ForegroundColor Yellow

Write-Host '  - ConfigMap...' -ForegroundColor Gray
kubectl delete -f config/configmap.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '  - Secrets...' -ForegroundColor Gray
kubectl delete -f infrastructure/postgresql/postgresql-secret.yaml -n shortify --ignore-not-found=true 2>&1 | Out-Null

Write-Host '[OK] Configuration deleted' -ForegroundColor Green
Write-Host ''

# Step 4: Wait for resources to terminate
Write-Host 'Step 4: Waiting for resources to terminate...' -ForegroundColor Yellow
Write-Host '  This may take a few minutes...' -ForegroundColor Gray

$maxWait = 300  # 5 minutes max wait
$elapsed = 0
$interval = 5

while ($elapsed -lt $maxWait) {
    $pods = kubectl get pods -n shortify --no-headers 2>&1
    if ($LASTEXITCODE -ne 0 -or $pods -eq $null -or $pods.Count -eq 0) {
        break
    }
    
    $runningPods = ($pods | Select-String -Pattern 'Running|Pending|Terminating').Count
    if ($runningPods -eq 0) {
        break
    }
    
    Write-Host "  Waiting... ($runningPods pods still terminating)" -ForegroundColor Gray
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

Write-Host '[OK] Resources terminated' -ForegroundColor Green
Write-Host ''

# Step 5: Delete namespace (this will clean up any remaining resources)
Write-Host 'Step 5: Deleting namespace...' -ForegroundColor Yellow

kubectl delete namespace shortify --ignore-not-found=true 2>&1 | Out-Null

# Wait for namespace deletion
$maxWait = 120  # 2 minutes max wait
$elapsed = 0
$interval = 2

while ($elapsed -lt $maxWait) {
    $ns = kubectl get namespace shortify --no-headers 2>&1
    if ($LASTEXITCODE -ne 0) {
        break
    }
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

Write-Host '[OK] Namespace deleted' -ForegroundColor Green
Write-Host ''

# Summary
Write-Host '================================================' -ForegroundColor Cyan
Write-Host 'Cleanup Complete!' -ForegroundColor Green
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'All Shortify services and infrastructure have been stopped and removed from Kubernetes.' -ForegroundColor Green
Write-Host ''
Write-Host 'Note: Persistent volumes (PVCs) are preserved by default.' -ForegroundColor Yellow
Write-Host 'To delete persistent volumes, run:' -ForegroundColor Yellow
Write-Host '  kubectl delete pvc --all -n shortify' -ForegroundColor Gray
Write-Host ''

# Restore original directory
Pop-Location

