# deploy-minimal.ps1
# Script PowerShell pour déployer la configuration minimale sur Kubernetes

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("deploy", "delete", "status", "logs", "restart")]
    [string]$Action = "deploy",
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ecom2micro-minimal"
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Deploy-Minimal {
    Write-ColorOutput "🚀 Déploiement minimal Kubernetes (16 GB)..." "Green"
    Write-ColorOutput "Namespace: $Namespace" "Cyan"
    
    # Vérifier que kubectl est disponible
    try {
        kubectl version --client | Out-Null
    }
    catch {
        Write-ColorOutput "❌ kubectl n'est pas installé ou pas dans le PATH" "Red"
        Write-ColorOutput "Installation: choco install kubernetes-cli" "Yellow"
        exit 1
    }
    
    # Vérifier la connexion au cluster
    Write-ColorOutput "`n🔍 Vérification du cluster..." "Cyan"
    try {
        $context = kubectl config current-context
        Write-ColorOutput "✅ Cluster: $context" "Green"
    }
    catch {
        Write-ColorOutput "❌ Pas de connexion au cluster Kubernetes" "Red"
        Write-ColorOutput "Démarrez Minikube: minikube start --memory=16384 --cpus=4" "Yellow"
        Write-ColorOutput "Ou activez Kubernetes dans Docker Desktop" "Yellow"
        exit 1
    }
    
    # Créer le namespace
    Write-ColorOutput "`n📦 Création du namespace..." "Cyan"
    kubectl apply -f namespace.yaml
    Start-Sleep -Seconds 2
    
    # Appliquer ConfigMap et Secrets
    Write-ColorOutput "`n🔧 Configuration..." "Cyan"
    kubectl apply -f configmap.yaml
    kubectl apply -f secrets.yaml
    Start-Sleep -Seconds 2
    
    # Déployer l'infrastructure
    Write-ColorOutput "`n🏗️  Déploiement infrastructure..." "Cyan"
    
    Write-ColorOutput "  → Zookeeper..." "Gray"
    kubectl apply -f kafka/zookeeper-statefulset.yaml
    Start-Sleep -Seconds 5
    
    Write-ColorOutput "  → PostgreSQL..." "Gray"
    kubectl apply -f postgres/postgres-configmap.yaml
    kubectl apply -f postgres/postgres-statefulset.yaml
    Start-Sleep -Seconds 5
    
    Write-ColorOutput "  → Redis..." "Gray"
    kubectl apply -f redis/redis-deployment.yaml
    Start-Sleep -Seconds 5
    
    Write-ColorOutput "`n⏳ Attente démarrage infrastructure (30s)..." "Yellow"
    Start-Sleep -Seconds 30
    
    Write-ColorOutput "  → Kafka..." "Gray"
    kubectl apply -f kafka/kafka-statefulset.yaml
    Start-Sleep -Seconds 10
    
    # Déployer les services
    Write-ColorOutput "`n🚀 Déploiement services..." "Cyan"
    
    Write-ColorOutput "  → Identity Service..." "Gray"
    kubectl apply -f services/identity-deployment.yaml
    
    Write-ColorOutput "  → Catalog Service..." "Gray"
    kubectl apply -f services/catalog-deployment.yaml
    
    Write-ColorOutput "  → Order Service..." "Gray"
    kubectl apply -f services/order-deployment.yaml
    
    Start-Sleep -Seconds 10
    
    Write-ColorOutput "  → API Gateway..." "Gray"
    kubectl apply -f services/gateway-deployment.yaml
    
    # Attendre que tous les pods soient prêts
    Write-ColorOutput "`n⏳ Attente démarrage des pods..." "Yellow"
    kubectl wait --for=condition=ready pod -l app=gateway -n $Namespace --timeout=120s
    
    Write-ColorOutput "`n✅ Déploiement terminé!" "Green"
    Show-Status
}

function Delete-Minimal {
    Write-ColorOutput "🗑️  Suppression du déploiement minimal..." "Red"
    
    $confirm = Read-Host "Êtes-vous sûr de vouloir supprimer tous les resources? (oui/non)"
    if ($confirm -ne "oui") {
        Write-ColorOutput "❌ Suppression annulée" "Yellow"
        return
    }
    
    Write-ColorOutput "`nSuppression en cours..." "Yellow"
    kubectl delete namespace $Namespace
    
    Write-ColorOutput "✅ Suppression terminée" "Green"
}

function Show-Status {
    Write-ColorOutput "`n📊 Status des déploiements:" "Cyan"
    kubectl get all -n $Namespace
    
    Write-ColorOutput "`n💾 Status des volumes:" "Cyan"
    kubectl get pvc -n $Namespace
    
    Write-ColorOutput "`n🔍 Pods en détail:" "Cyan"
    kubectl get pods -n $Namespace -o wide
    
    Write-ColorOutput "`n🌐 Services:" "Cyan"
    kubectl get svc -n $Namespace
    
    Write-ColorOutput "`n📈 Utilisation ressources:" "Cyan"
    try {
        kubectl top pods -n $Namespace 2>$null
        kubectl top nodes 2>$null
    }
    catch {
        Write-ColorOutput "⚠️  Metrics-server non installé (kubectl top indisponible)" "Yellow"
        Write-ColorOutput "Pour Minikube: minikube addons enable metrics-server" "Gray"
    }
    
    Write-ColorOutput "`n🔗 Accès aux services:" "Cyan"
    Write-ColorOutput "Port-forward Gateway:" "Gray"
    Write-ColorOutput "  kubectl port-forward svc/gateway-service 5000:5000 -n $Namespace" "White"
    Write-ColorOutput "  Puis: http://localhost:5000" "White"
    
    Write-ColorOutput "`nOu avec Minikube:" "Gray"
    Write-ColorOutput "  minikube service gateway-service -n $Namespace" "White"
}

function Show-Logs {
    Write-ColorOutput "📋 Logs des services..." "Cyan"
    
    $services = @("gateway", "identity", "catalog", "order", "kafka", "postgres", "redis")
    
    foreach ($service in $services) {
        Write-ColorOutput "`n=== $service ===" "Yellow"
        $pods = kubectl get pods -n $Namespace -l app=$service -o jsonpath='{.items[0].metadata.name}' 2>$null
        if ($pods) {
            kubectl logs --tail=20 $pods -n $Namespace
        }
        else {
            Write-ColorOutput "  Aucun pod trouvé" "Gray"
        }
    }
}

function Restart-Services {
    Write-ColorOutput "🔄 Redémarrage des services..." "Cyan"
    
    kubectl rollout restart deployment -n $Namespace
    kubectl rollout restart statefulset -n $Namespace
    
    Write-ColorOutput "⏳ Attente du redémarrage..." "Yellow"
    kubectl rollout status deployment -n $Namespace --timeout=120s
    
    Write-ColorOutput "✅ Redémarrage terminé" "Green"
    Show-Status
}

# Main
switch ($Action) {
    "deploy" {
        Deploy-Minimal
    }
    "delete" {
        Delete-Minimal
    }
    "status" {
        Show-Status
    }
    "logs" {
        Show-Logs
    }
    "restart" {
        Restart-Services
    }
    default {
        Write-ColorOutput "❌ Action invalide: $Action" "Red"
        Write-ColorOutput "Actions disponibles: deploy, delete, status, logs, restart" "Yellow"
        exit 1
    }
}
