# Déploiement Kubernetes Minimal (16 GB)

Configuration ultra-minimale pour déployer ecom2micro sur Kubernetes avec seulement **16 GB de RAM**.

## 🎯 Caractéristiques

- **RAM Total**: ~13-16 GB
- **Infrastructure**: Kafka (4 GB), PostgreSQL multi-schéma (4 GB), Redis (1 GB)
- **Services**: API Gateway, Identity, Catalog, Order
- **Monitoring**: Désactivé
- **Scalabilité**: 1 replica par service

## 📋 Prérequis

### 1. Cluster Kubernetes

**Option A - Minikube (Local)**
```bash
# Installer Minikube
choco install minikube

# Démarrer avec 16 GB RAM
minikube start --memory=16384 --cpus=4 --disk-size=50g

# Vérifier le cluster
kubectl cluster-info
```

**Option B - Docker Desktop Kubernetes (Local)**
```powershell
# Activer Kubernetes dans Docker Desktop
# Settings → Kubernetes → Enable Kubernetes
# Resources → Memory: 16 GB, CPUs: 4

# Vérifier le contexte
kubectl config current-context
```

**Option C - Cloud (AKS, EKS, GKE)**
```bash
# Azure AKS
az aks create \
  --resource-group ecom2micro-rg \
  --name ecom2micro-minimal \
  --node-count 2 \
  --node-vm-size Standard_D4s_v3 \
  --enable-addons monitoring

# AWS EKS
eksctl create cluster \
  --name ecom2micro-minimal \
  --region us-west-2 \
  --node-type t3.xlarge \
  --nodes 2

# Google GKE
gcloud container clusters create ecom2micro-minimal \
  --machine-type n1-standard-4 \
  --num-nodes 2 \
  --region us-central1
```

### 2. Outils requis

```bash
# kubectl
choco install kubernetes-cli

# kustomize (optionnel)
choco install kustomize

# helm (optionnel)
choco install kubernetes-helm
```

### 3. Images Docker

Les services doivent être buildés et disponibles. Deux options :

**Option A - Build Local**
```bash
cd backend/src
docker build -t ecom2micro/api-gateway:latest -f ApiGateway/Dockerfile .
docker build -t ecom2micro/identity-service:latest -f Services/Identity/Identity.API/Dockerfile .
docker build -t ecom2micro/catalog-service:latest -f Services/Catalog/Catalog.API/Dockerfile .
docker build -t ecom2micro/order-service:latest -f Services/Order/Order.API/Dockerfile .

# Si Minikube, charger les images
minikube image load ecom2micro/api-gateway:latest
minikube image load ecom2micro/identity-service:latest
minikube image load ecom2micro/catalog-service:latest
minikube image load ecom2micro/order-service:latest
```

**Option B - Registry privé**
```bash
# Tag et push vers registry
docker tag ecom2micro/api-gateway:latest myregistry.azurecr.io/api-gateway:latest
docker push myregistry.azurecr.io/api-gateway:latest
# ... répéter pour chaque service

# Créer secret pour pull
kubectl create secret docker-registry acr-secret \
  --docker-server=myregistry.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace=ecom2micro-minimal

# Ajouter imagePullSecrets dans les deployments
```

## 🚀 Déploiement

### Méthode 1 - Kubectl Apply

```bash
# Depuis la racine du projet
cd k8s/minimal

# Déployer tous les manifests
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f kafka/
kubectl apply -f postgres/
kubectl apply -f redis/
kubectl apply -f services/

# Ou tout en une fois
kubectl apply -f .
```

### Méthode 2 - Kustomize

```bash
cd k8s/minimal

# Prévisualiser
kubectl kustomize .

# Déployer
kubectl apply -k .
```

### Méthode 3 - Script PowerShell

```powershell
# deploy-minimal.ps1
cd k8s/minimal

Write-Host "🚀 Déploiement minimal Kubernetes..." -ForegroundColor Green

# Apply dans l'ordre
kubectl apply -f namespace.yaml
Start-Sleep -Seconds 2

kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
Start-Sleep -Seconds 2

Write-Host "📦 Déploiement infrastructure..." -ForegroundColor Cyan
kubectl apply -f kafka/zookeeper-statefulset.yaml
Start-Sleep -Seconds 10

kubectl apply -f kafka/kafka-statefulset.yaml
kubectl apply -f postgres/postgres-configmap.yaml
kubectl apply -f postgres/postgres-statefulset.yaml
kubectl apply -f redis/redis-deployment.yaml
Start-Sleep -Seconds 30

Write-Host "🔧 Déploiement services..." -ForegroundColor Cyan
kubectl apply -f services/identity-deployment.yaml
kubectl apply -f services/catalog-deployment.yaml
kubectl apply -f services/order-deployment.yaml
Start-Sleep -Seconds 10

kubectl apply -f services/gateway-deployment.yaml

Write-Host "✅ Déploiement terminé!" -ForegroundColor Green
```

## 📊 Vérification

### 1. Status des pods

```bash
# Tous les pods
kubectl get pods -n ecom2micro-minimal

# Watch en temps réel
kubectl get pods -n ecom2micro-minimal -w

# Détails d'un pod
kubectl describe pod <pod-name> -n ecom2micro-minimal

# Logs
kubectl logs -f <pod-name> -n ecom2micro-minimal
```

### 2. Services et endpoints

```bash
# Liste des services
kubectl get svc -n ecom2micro-minimal

# Endpoints
kubectl get endpoints -n ecom2micro-minimal
```

### 3. Utilisation des ressources

```bash
# Usage par pod
kubectl top pods -n ecom2micro-minimal

# Usage par node
kubectl top nodes

# Détails complets
kubectl describe nodes
```

### 4. Health checks

```bash
# Port-forward pour tester
kubectl port-forward svc/gateway-service 5000:5000 -n ecom2micro-minimal

# Tester les endpoints (nouveau terminal)
curl http://localhost:5000/health/live
curl http://localhost:5000/health/ready

# Health de chaque service
kubectl port-forward svc/identity-service 5001:5001 -n ecom2micro-minimal
curl http://localhost:5001/health/live

kubectl port-forward svc/catalog-service 5002:5002 -n ecom2micro-minimal
curl http://localhost:5002/health/live

kubectl port-forward svc/order-service 5004:5004 -n ecom2micro-minimal
curl http://localhost:5004/health/live
```

## 🔧 Configuration

### Modifier les secrets

```bash
# Encoder en base64
echo -n "new-password" | base64

# Éditer le secret
kubectl edit secret app-secrets -n ecom2micro-minimal

# Ou supprimer et recréer
kubectl delete secret app-secrets -n ecom2micro-minimal
kubectl apply -f secrets.yaml
```

### Modifier la configuration

```bash
# Éditer ConfigMap
kubectl edit configmap app-config -n ecom2micro-minimal

# Redémarrer les pods pour appliquer
kubectl rollout restart deployment -n ecom2micro-minimal
kubectl rollout restart statefulset -n ecom2micro-minimal
```

### Scaler les services

```bash
# Scaler un service
kubectl scale deployment catalog --replicas=2 -n ecom2micro-minimal

# Scaler Kafka (attention: nécessite plus de RAM)
kubectl scale statefulset kafka --replicas=2 -n ecom2micro-minimal

# Auto-scaling (HPA)
kubectl autoscale deployment catalog \
  --cpu-percent=70 \
  --min=1 \
  --max=3 \
  -n ecom2micro-minimal
```

## 🌐 Accès externe

### Méthode 1 - Port Forward (Dev)

```bash
# Gateway
kubectl port-forward svc/gateway-service 5000:5000 -n ecom2micro-minimal

# Accès: http://localhost:5000
```

### Méthode 2 - NodePort (Minikube)

```bash
# Modifier gateway-service
kubectl patch svc gateway-service -n ecom2micro-minimal -p '{"spec":{"type":"NodePort"}}'

# Obtenir l'URL
minikube service gateway-service -n ecom2micro-minimal --url

# Accès: http://192.168.49.2:30xxx
```

### Méthode 3 - Ingress (Production)

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecom2micro-ingress
  namespace: ecom2micro-minimal
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: ecom2micro.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gateway-service
            port:
              number: 5000
```

```bash
# Installer nginx-ingress (Minikube)
minikube addons enable ingress

# Ou avec Helm
helm install nginx-ingress ingress-nginx/ingress-nginx

# Apply ingress
kubectl apply -f ingress.yaml

# Ajouter au hosts (Windows: C:\Windows\System32\drivers\etc\hosts)
192.168.49.2 ecom2micro.local

# Accès: http://ecom2micro.local
```

### Méthode 4 - LoadBalancer (Cloud)

Le service `gateway-service` est déjà de type `LoadBalancer`. Sur AKS/EKS/GKE, un IP publique sera automatiquement assignée.

```bash
# Obtenir l'IP externe (prend 2-3 minutes)
kubectl get svc gateway-service -n ecom2micro-minimal -w

# Accès: http://<EXTERNAL-IP>:5000
```

## 🔍 Debugging

### Logs

```bash
# Logs d'un pod
kubectl logs -f <pod-name> -n ecom2micro-minimal

# Logs des 100 dernières lignes
kubectl logs --tail=100 <pod-name> -n ecom2micro-minimal

# Logs de tous les pods d'un deployment
kubectl logs -l app=catalog -n ecom2micro-minimal

# Logs du conteneur précédent (si crashé)
kubectl logs <pod-name> -n ecom2micro-minimal --previous
```

### Shell dans un pod

```bash
# Bash dans un pod
kubectl exec -it <pod-name> -n ecom2micro-minimal -- /bin/bash

# Sh dans alpine
kubectl exec -it <pod-name> -n ecom2micro-minimal -- /bin/sh

# Commande directe
kubectl exec <pod-name> -n ecom2micro-minimal -- env
```

### Problèmes courants

**1. Pods en CrashLoopBackOff**
```bash
# Voir les logs
kubectl logs <pod-name> -n ecom2micro-minimal

# Voir les events
kubectl describe pod <pod-name> -n ecom2micro-minimal

# Causes fréquentes:
# - Images non disponibles (imagePullPolicy: IfNotPresent)
# - Connexion DB échouée (vérifier postgres-service)
# - Connexion Kafka échouée (attendre que Kafka démarre)
```

**2. ImagePullBackOff**
```bash
# Vérifier les images disponibles (Minikube)
minikube ssh
docker images | grep ecom2micro

# Charger l'image manquante
minikube image load ecom2micro/catalog-service:latest
```

**3. PVC Pending**
```bash
# Vérifier PVC
kubectl get pvc -n ecom2micro-minimal

# Vérifier StorageClass
kubectl get storageclass

# Minikube: créer StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
EOF
```

**4. Service inaccessible**
```bash
# Vérifier endpoints
kubectl get endpoints gateway-service -n ecom2micro-minimal

# Si vide, pods pas prêts
kubectl get pods -n ecom2micro-minimal

# Tester DNS interne
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup gateway-service.ecom2micro-minimal.svc.cluster.local
```

## 🧹 Nettoyage

```bash
# Supprimer tous les resources
kubectl delete namespace ecom2micro-minimal

# Ou supprimer avec kustomize
kubectl delete -k k8s/minimal/

# Ou individuellement
kubectl delete -f k8s/minimal/services/
kubectl delete -f k8s/minimal/redis/
kubectl delete -f k8s/minimal/postgres/
kubectl delete -f k8s/minimal/kafka/
kubectl delete -f k8s/minimal/configmap.yaml
kubectl delete -f k8s/minimal/secrets.yaml
kubectl delete -f k8s/minimal/namespace.yaml
```

## 📦 Volumes et données

### Backup PostgreSQL

```bash
# Exec dans le pod PostgreSQL
kubectl exec -it postgres-0 -n ecom2micro-minimal -- bash

# Backup toutes les DBs
pg_dump -U postgres ecom2micro > /tmp/backup.sql

# Copier le backup localement
kubectl cp ecom2micro-minimal/postgres-0:/tmp/backup.sql ./backup.sql

# Restore
kubectl cp ./backup.sql ecom2micro-minimal/postgres-0:/tmp/restore.sql
kubectl exec -it postgres-0 -n ecom2micro-minimal -- psql -U postgres ecom2micro < /tmp/restore.sql
```

### Backup PVC

```bash
# Créer un snapshot (Cloud)
kubectl get pvc -n ecom2micro-minimal

# Backup manuel
kubectl exec postgres-0 -n ecom2micro-minimal -- tar czf - /var/lib/postgresql/data | gzip > postgres-backup.tar.gz
```

## 🔄 Mise à jour

### Rolling update

```bash
# Mettre à jour l'image d'un service
kubectl set image deployment/catalog catalog=ecom2micro/catalog-service:v2.0 -n ecom2micro-minimal

# Suivre le rollout
kubectl rollout status deployment/catalog -n ecom2micro-minimal

# Rollback si problème
kubectl rollout undo deployment/catalog -n ecom2micro-minimal
```

## 📈 Monitoring

### Métriques serveur

```bash
# Installer metrics-server (Minikube)
minikube addons enable metrics-server

# Voir les métriques
kubectl top pods -n ecom2micro-minimal
kubectl top nodes
```

### Dashboard Kubernetes

```bash
# Installer dashboard (Minikube)
minikube dashboard

# Ou manuellement
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Créer token d'accès
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin
kubectl -n kubernetes-dashboard create token dashboard-admin

# Accéder
kubectl proxy
# http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## 🎯 Usage RAM

Utilisation réelle attendue:

| Composant | Request | Limit | Pods | Total |
|-----------|---------|-------|------|-------|
| Zookeeper | 384 Mi | 512 Mi | 1 | 512 Mi |
| Kafka | 3 Gi | 4 Gi | 1 | 4 Gi |
| PostgreSQL | 3 Gi | 4 Gi | 1 | 4 Gi |
| Redis | 768 Mi | 1 Gi | 1 | 1 Gi |
| API Gateway | 256 Mi | 384 Mi | 1 | 384 Mi |
| Identity | 384 Mi | 512 Mi | 1 | 512 Mi |
| Catalog | 512 Mi | 768 Mi | 1 | 768 Mi |
| Order | 512 Mi | 768 Mi | 1 | 768 Mi |
| **Total** | | | | **~12.9 Gi** |

Avec overhead Kubernetes (~2-3 GB): **~15-16 GB total**

## 🔐 Sécurité

### Secrets management

```bash
# Utiliser Sealed Secrets (recommandé)
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Sceller un secret
kubeseal --format=yaml < secrets.yaml > sealed-secrets.yaml
kubectl apply -f sealed-secrets.yaml
```

### Network Policies

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: ecom2micro-minimal
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-gateway
  namespace: ecom2micro-minimal
spec:
  podSelector:
    matchLabels:
      app: gateway
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 5000
```

## 📚 Ressources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Guide](https://minikube.sigs.k8s.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kustomize](https://kustomize.io/)
- [Helm Charts](https://helm.sh/)
