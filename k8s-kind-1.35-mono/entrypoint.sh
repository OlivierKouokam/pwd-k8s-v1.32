#!/bin/bash
# entrypoint.sh

set -e

echo "========================================"
echo "🚀 Démarrage de PWD K8s Mono"
echo "========================================"

# Fonction pour logger
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 1. Démarrer systemd
log "Démarrage de systemd..."
exec /usr/lib/systemd/systemd --system --unit=multi-user.target &
SYSTEMD_PID=$!

# Attendre que systemd soit prêt
sleep 5
log "Systemd démarré (PID: $SYSTEMD_PID)"

# 2. Initialiser Kubernetes
log "Initialisation de Kubernetes..."
/usr/local/bin/init-k8s.sh

# 3. Configurer kubectl pour l'hôte
log "Configuration de kubectl..."
mkdir -p /etc/kubernetes/pki
mkdir -p /root/.kube

# Copier la config admin
if [ -f /etc/kubernetes/admin.conf ]; then
    cp /etc/kubernetes/admin.conf /root/.kube/config
    chmod 600 /root/.kube/config
    
    # Rendre la config accessible de l'extérieur
    cp /etc/kubernetes/admin.conf /kubeconfig.yaml
    chmod 644 /kubeconfig.yaml
    
    log "Kubeconfig disponible à: /kubeconfig.yaml"
fi

# 4. Démarrer les services additionnels
log "Démarrage des services Kubernetes..."
systemctl start containerd
systemctl start kubelet

# Attendre que l'API soit disponible
log "Attente de l'API Kubernetes..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes 2>/dev/null; then
        log "✅ API Kubernetes disponible!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT+1))
    sleep 10
    log "Tentative $RETRY_COUNT/$MAX_RETRIES..."
done

# 5. Créer un service NodePort de test (optionnel)
log "Création d'un service de démonstration..."
cat > /tmp/test-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx-test
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/test-deployment.yaml

# 6. Afficher les informations
log "========================================"
log "✅ Kubernetes est prêt !"
log ""
log "Informations du cluster:"
kubectl --kubeconfig=/etc/kubernetes/admin.conf cluster-info
log ""
log "Nodes:"
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
log ""
log "Services:"
kubectl --kubeconfig=/etc/kubernetes/admin.conf get svc -A | grep -E "(nginx-service|kubernetes)"
log ""
log "========================================"
log "📊 Pour utiliser kubectl depuis l'hôte:"
log "1. Récupérer le kubeconfig:"
log "   docker cp <container_id>:/kubeconfig.yaml ."
log "2. Utiliser:"
log "   kubectl --kubeconfig=kubeconfig.yaml get nodes"
log ""
log "🌐 Services exposés sur PWD:"
log "   - Kubernetes API: 6443"
log "   - Service test: 30080"
log "========================================"

# 7. Garder le conteneur en vie et surveiller
log "Surveillance des services..."
/usr/local/bin/healthcheck.sh