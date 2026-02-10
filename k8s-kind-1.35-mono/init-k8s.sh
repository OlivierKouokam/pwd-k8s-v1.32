#!/bin/bash
# init-k8s.sh

set -e

echo "========================================"
echo "🚀 PWD K8s Mono - Initialisation"
echo "========================================"

# Attendre que containerd soit démarré par l'entrypoint original de Kind
echo "⏳ Attente de containerd..."
while [ ! -S /run/containerd/containerd.sock ]; do
    sleep 1
done
echo "✅ containerd prêt"

# Attendre que l'initialisation système soit complète
sleep 5

# Vérifier si Kubernetes est déjà initialisé
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "✅ Kubernetes déjà initialisé"
else
    echo "🔧 Initialisation de Kubernetes..."
    
    # Utiliser la config kubeadm de Kind (déjà présente)
    if [ -f /kind/kubeadm.conf ]; then
        echo "📁 Utilisation de la configuration Kind..."
        kubeadm init --config=/kind/kubeadm.conf --skip-phases=addon/kube-proxy --ignore-preflight-errors=SystemVerification,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables
    else
        echo "📁 Création de configuration par défaut..."
        cat > /tmp/kubeadm.conf << 'EOF'
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    node-labels: "ingress-ready=true"
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
apiServer:
  certSANs:
  - localhost
  - 127.0.0.1
  - 0.0.0.0
controllerManager:
  extraArgs:
    enable-hostpath-provisioner: "true"
networking:
  podSubnet: "10.244.0.0/16"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
        kubeadm init --config=/tmp/kubeadm.conf --ignore-preflight-errors=all
    fi
    
    echo "✅ Kubernetes initialisé"
fi

# Configurer kubectl
echo "⚙️ Configuration de kubectl..."
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# Créer un kubeconfig accessible
cp /etc/kubernetes/admin.conf /kubeconfig
chmod 644 /kubeconfig

# Appliquer le réseau Calico (ou kindnet si disponible)
echo "🌐 Configuration du réseau..."
if [ -f /kind/manifests/default-cni.yaml ]; then
    kubectl apply -f /kind/manifests/default-cni.yaml
else
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
fi

# Attendre que le réseau soit prêt
echo "⏳ Attente du réseau..."
sleep 30

# Créer un service de test pour PWD
echo "🧪 Création d'un service de test..."
cat > /tmp/test-app.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pwd-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pwd-test
  template:
    metadata:
      labels:
        app: pwd-test
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
  name: pwd-test-service
spec:
  type: NodePort
  selector:
    app: pwd-test
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

kubectl apply -f /tmp/test-app.yaml

# Afficher les informations
echo "========================================"
echo "✅ PWD K8s Mono Prêt !"
echo ""
echo "📊 Cluster Info:"
kubectl cluster-info
echo ""
echo "📦 Pods système:"
kubectl get pods -n kube-system
echo ""
echo "🔗 Kubeconfig disponible:"
echo "   À l'intérieur du conteneur: /kubeconfig"
echo "   Pour copier: docker cp <container>:/kubeconfig ."
echo ""
echo "🌐 Service de test:"
echo "   Port: 30080"
echo "   Sur PWD: ouvrir le port 30080"
echo "========================================"

# Garder le conteneur en vie
echo "🔄 En cours d'exécution..."
tail -f /dev/null