# Production-Ready Kubernetes Deployment Script (PowerShell)
# Deploys all infrastructure and application services

Write-Host '================================================' -ForegroundColor Cyan
Write-Host 'Deploying Shortify Services to Kubernetes' -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ""

# Check if kubectl is available
try {
    kubectl version --client | Out-Null
    Write-Host '[OK] kubectl is available' -ForegroundColor Green
} catch {
    Write-Host '[ERROR] kubectl is not installed or not in PATH' -ForegroundColor Red
    exit 1
}

# Check if kubectl can connect to cluster
try {
    kubectl cluster-info | Out-Null
    Write-Host '[OK] Kubernetes cluster is accessible' -ForegroundColor Green
} catch {
    Write-Host '[ERROR] Cannot connect to Kubernetes cluster' -ForegroundColor Red
    Write-Host "Please ensure kubectl is configured correctly" -ForegroundColor Yellow
    exit 1
}

# Check if Docker is available
try {
    docker version | Out-Null
    Write-Host '[OK] Docker is available' -ForegroundColor Green
} catch {
    Write-Host '[ERROR] Docker is not installed or not running' -ForegroundColor Red
    Write-Host "Please ensure Docker Desktop is running" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Change to k8s directory (parent of scripts directory)
$k8sDir = Split-Path -Parent $PSScriptRoot
Push-Location $k8sDir

# Step 0: Build Docker images
Write-Host 'Step 0: Building Docker images...' -ForegroundColor Yellow
Write-Host '  This may take several minutes on first build...' -ForegroundColor Gray
Write-Host ""

# Get the project root directory (parent of k8s/)
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    Write-Host "  Building create-service..." -ForegroundColor Gray
    docker build -f create-service/Dockerfile -t shortify/create-service:latest .
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[ERROR] Failed to build create-service image' -ForegroundColor Red
        exit 1
    }
    Write-Host '    [OK] create-service image built' -ForegroundColor Green

    Write-Host "  Building lookup-service..." -ForegroundColor Gray
    docker build -f lookup-service/Dockerfile -t shortify/lookup-service:latest .
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[ERROR] Failed to build lookup-service image' -ForegroundColor Red
        exit 1
    }
    Write-Host '    [OK] lookup-service image built' -ForegroundColor Green

    Write-Host "  Building api-gateway..." -ForegroundColor Gray
    docker build -f api-gateway/Dockerfile -t shortify/api-gateway:latest .
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[ERROR] Failed to build api-gateway image' -ForegroundColor Red
        exit 1
    }
    Write-Host '    [OK] api-gateway image built' -ForegroundColor Green

    Write-Host "  Building stats-service..." -ForegroundColor Gray
    docker build -f stats-service/Dockerfile -t shortify/stats-service:latest .
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[ERROR] Failed to build stats-service image' -ForegroundColor Red
        exit 1
    }
    Write-Host '    [OK] stats-service image built' -ForegroundColor Green

    Write-Host '[OK] All Docker images built successfully' -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host '[ERROR] Error building Docker images: $_' -ForegroundColor Red
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

# Change to k8s directory for kubectl commands
$k8sDir = Split-Path -Parent $PSScriptRoot
Push-Location $k8sDir

# Step 1: Create namespace
Write-Host 'Step 1: Creating namespace...' -ForegroundColor Yellow
kubectl apply -f config/namespace.yaml
if ($LASTEXITCODE -eq 0) {
    Write-Host '[OK] Namespace created' -ForegroundColor Green
} else {
    Write-Host '[ERROR] Failed to create namespace' -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 2: Create secrets
Write-Host 'Step 2: Creating secrets...' -ForegroundColor Yellow
kubectl apply -f infrastructure/postgresql/postgresql-secret.yaml
if ($LASTEXITCODE -eq 0) {
    Write-Host '[OK] Secrets created' -ForegroundColor Green
} else {
    Write-Host '[ERROR] Failed to create secrets' -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 3: Deploy infrastructure services
Write-Host 'Step 3: Deploying infrastructure services...' -ForegroundColor Yellow
Write-Host "  - PostgreSQL Primary..." -ForegroundColor Gray
kubectl apply -f infrastructure/postgresql/postgresql-primary.yaml
Write-Host "  - PostgreSQL Replica 1..." -ForegroundColor Gray
kubectl apply -f infrastructure/postgresql/postgresql-replica-1.yaml
Write-Host "  - PostgreSQL Replica 2..." -ForegroundColor Gray
kubectl apply -f infrastructure/postgresql/postgresql-replica-2.yaml
Write-Host "  - PostgreSQL Replica 3..." -ForegroundColor Gray
kubectl apply -f infrastructure/postgresql/postgresql-replica-3.yaml
Write-Host "  - PostgreSQL Replicas Service..." -ForegroundColor Gray
kubectl apply -f infrastructure/postgresql/postgresql-replicas-service.yaml
Write-Host "  - PostgreSQL Stats..." -ForegroundColor Gray
kubectl apply -f infrastructure/postgresql/postgresql-stats.yaml
Write-Host "  - Redis Cluster Node 1..." -ForegroundColor Gray
kubectl apply -f infrastructure/redis/redis-cluster-node-1.yaml
Write-Host "  - Redis Cluster Node 2..." -ForegroundColor Gray
kubectl apply -f infrastructure/redis/redis-cluster-node-2.yaml
Write-Host "  - Redis Cluster Node 3..." -ForegroundColor Gray
kubectl apply -f infrastructure/redis/redis-cluster-node-3.yaml
Write-Host "  - Redis Cluster Node 4..." -ForegroundColor Gray
kubectl apply -f infrastructure/redis/redis-cluster-node-4.yaml
Write-Host "  - Redis Cluster Node 5..." -ForegroundColor Gray
kubectl apply -f infrastructure/redis/redis-cluster-node-5.yaml
Write-Host "  - Redis Cluster Node 6..." -ForegroundColor Gray
kubectl apply -f infrastructure/redis/redis-cluster-node-6.yaml
Write-Host "  - Redis Cluster Service..." -ForegroundColor Gray
kubectl apply -f infrastructure/redis/redis-cluster-service.yaml
Write-Host "  - Zookeeper..." -ForegroundColor Gray
kubectl apply -f infrastructure/kafka/kafka-zookeeper.yaml
Write-Host "  - Kafka Broker 1..." -ForegroundColor Gray
kubectl apply -f infrastructure/kafka/kafka-broker-1.yaml
Write-Host "  - Kafka Broker 2..." -ForegroundColor Gray
kubectl apply -f infrastructure/kafka/kafka-broker-2.yaml
Write-Host "  - Kafka Broker 3..." -ForegroundColor Gray
kubectl apply -f infrastructure/kafka/kafka-broker-3.yaml
Write-Host "  - Kafka Cluster Service..." -ForegroundColor Gray
kubectl apply -f infrastructure/kafka/kafka-cluster-service.yaml
Write-Host '[OK] Infrastructure services deployed' -ForegroundColor Green
Write-Host ""

# Step 4: Wait for infrastructure to be ready
Write-Host 'Step 4: Waiting for infrastructure to be ready...' -ForegroundColor Yellow
Write-Host "  Waiting for PostgreSQL Primary..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=postgresql-primary -n shortify --timeout=300s
Write-Host "  Waiting for PostgreSQL Replica 1..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=postgresql-replica-1 -n shortify --timeout=300s
Write-Host "  Waiting for PostgreSQL Replica 2..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=postgresql-replica-2 -n shortify --timeout=300s
Write-Host "  Waiting for PostgreSQL Replica 3..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=postgresql-replica-3 -n shortify --timeout=300s
Write-Host "  Waiting for PostgreSQL Stats..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=postgresql-stats -n shortify --timeout=300s
Write-Host "  Waiting for Redis Cluster Nodes..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=redis-node-1 -n shortify --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis-node-2 -n shortify --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis-node-3 -n shortify --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis-node-4 -n shortify --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis-node-5 -n shortify --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis-node-6 -n shortify --timeout=300s
Write-Host "  Initializing Redis Cluster..." -ForegroundColor Gray
kubectl apply -f infrastructure/redis/redis-cluster-init-job.yaml
Write-Host "  Waiting for Redis Cluster initialization..." -ForegroundColor Gray
kubectl wait --for=condition=complete job/redis-cluster-init -n shortify --timeout=300s 2>&1 | Out-Null
Write-Host "  Waiting for Zookeeper..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=zookeeper -n shortify --timeout=300s
Write-Host "  Waiting for Kafka Brokers..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=kafka-broker-1 -n shortify --timeout=300s
kubectl wait --for=condition=ready pod -l app=kafka-broker-2 -n shortify --timeout=300s
kubectl wait --for=condition=ready pod -l app=kafka-broker-3 -n shortify --timeout=300s
Write-Host '[OK] Infrastructure is ready' -ForegroundColor Green
Write-Host ""

# Step 5: Create ConfigMap
Write-Host 'Step 5: Creating ConfigMap...' -ForegroundColor Yellow
kubectl apply -f config/configmap.yaml
if ($LASTEXITCODE -eq 0) {
    Write-Host '[OK] ConfigMap created' -ForegroundColor Green
} else {
    Write-Host '[ERROR] Failed to create ConfigMap' -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 6: Deploy application services
Write-Host 'Step 6: Deploying application services...' -ForegroundColor Yellow
Write-Host "  - API Gateway..." -ForegroundColor Gray
kubectl apply -f services/api-gateway-deployment.yaml
Write-Host "  - Create Service..." -ForegroundColor Gray
kubectl apply -f services/create-service-deployment.yaml
Write-Host "  - Lookup Service..." -ForegroundColor Gray
kubectl apply -f services/lookup-service-deployment.yaml
Write-Host "  - Stats Service..." -ForegroundColor Gray
kubectl apply -f services/stats-service-deployment.yaml
Write-Host "  - API Gateway HPA..." -ForegroundColor Gray
kubectl apply -f services/api-gateway-hpa.yaml
Write-Host "  - Ingress..." -ForegroundColor Gray
kubectl apply -f config/ingress.yaml
Write-Host '[OK] Application services deployed' -ForegroundColor Green
Write-Host ""

# Step 7: Wait for application services to be ready
Write-Host 'Step 7: Waiting for application services to be ready...' -ForegroundColor Yellow
Write-Host "  Waiting for API Gateway..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=api-gateway -n shortify --timeout=300s 2>&1 | Out-Null
Write-Host "  Waiting for Create Service..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=create-service -n shortify --timeout=300s 2>&1 | Out-Null
Write-Host "  Waiting for Lookup Service..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=lookup-service -n shortify --timeout=300s 2>&1 | Out-Null
Write-Host "  Waiting for Stats Service..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=stats-service -n shortify --timeout=300s 2>&1 | Out-Null
Write-Host 'Application services are starting' -ForegroundColor Green
Write-Host ""

# Step 8: Show status
Write-Host 'Step 8: Deployment Status' -ForegroundColor Yellow
Write-Host ""
Write-Host 'Pods:' -ForegroundColor Cyan
kubectl get pods -n shortify
Write-Host ""
Write-Host 'Services:' -ForegroundColor Cyan
kubectl get svc -n shortify
Write-Host ""
Write-Host 'HPA:' -ForegroundColor Cyan
kubectl get hpa -n shortify
Write-Host ""

Write-Host '================================================' -ForegroundColor Cyan
Write-Host 'Deployment Complete!' -ForegroundColor Green
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ""
Write-Host 'Access Services:' -ForegroundColor Yellow
Write-Host '  Option 1: Port Forward (Quick Test):' -ForegroundColor Cyan
Write-Host '    kubectl port-forward svc/api-gateway 8080:8080 -n shortify' -ForegroundColor White
Write-Host '    Then access: http://localhost:8080' -ForegroundColor White
Write-Host ""
Write-Host '  Option 2: Ingress (Production):' -ForegroundColor Cyan
Write-Host '    Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts):' -ForegroundColor White
Write-Host '    127.0.0.1 shortify.local' -ForegroundColor Gray
Write-Host '    Then access: http://shortify.local' -ForegroundColor White
Write-Host '    (Requires NGINX Ingress Controller installed)' -ForegroundColor Gray
Write-Host ""
Write-Host 'View Logs:' -ForegroundColor Yellow
Write-Host '  - API Gateway: kubectl logs -f deployment/api-gateway -n shortify' -ForegroundColor White
Write-Host '  - Create Service: kubectl logs -f deployment/create-service -n shortify' -ForegroundColor White
Write-Host '  - Lookup Service: kubectl logs -f deployment/lookup-service -n shortify' -ForegroundColor White
Write-Host '  - Stats Service: kubectl logs -f deployment/stats-service -n shortify' -ForegroundColor White
Write-Host ""
Write-Host 'Monitor Auto-Scaling:' -ForegroundColor Yellow
Write-Host '  - kubectl get hpa -n shortify -w' -ForegroundColor White
Write-Host '  - kubectl get pods -n shortify -w' -ForegroundColor White
Write-Host ""

# Restore original directory
Pop-Location

