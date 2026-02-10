#!/bin/bash
# init-k8s.sh

set -e

echo "🔧 Initialisation complète de Kubernetes..."

# Créer la configuration kubeadm si elle n'existe pas
if [ ! -f /etc/kubernetes/kubeadm-config.yaml ]; then
    cat > /etc/kubernetes/kubeadm-config.yaml << 'EOF'
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    cgroup-driver: systemd
    fail-swap-on: false
    node-labels: "pwd-ready=true,env=development"
    max-pods: "250"
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
apiServer:
  certSANs:
  - localhost
  - 127.0.0.1
  - 0.0.0.0
  extraArgs:
    advertise-address: 0.0.0.0
    runtime-config: "api/all=true"
controlPlaneEndpoint: "0.0.0.0:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  serviceNodePortRange: "30000-32767"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: iptables
clusterCIDR: "10.244.0.0/16"
EOF
fi

# Initialiser le cluster
echo "🚀 kubeadm init avec tous les ports NodePort (30000-32767)..."
kubeadm init \
    --config=/etc/kubernetes/kubeadm-config.yaml \
    --ignore-preflight-errors=all \
    --upload-certs \
    --v=5

# Configurer kubectl
echo "⚙️  Configuration de kubectl..."
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chmod 600 /root/.kube/config

# Créer un kubeconfig accessible
cp /etc/kubernetes/admin.conf /kubeconfig
chmod 644 /kubeconfig

# Appliquer Flannel CNI
echo "🌐 Installation de Flannel..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Attendre les pods système
echo "⏳ Attente des pods système..."
sleep 30

# Créer des déploiements de test pour différents ports
echo "🧪 Création de services de test sur différents ports..."

# Service sur 30080
cat > /tmp/test-30080.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-30080
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-30080
  template:
    metadata:
      labels:
        app: test-30080
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
  name: test-30080
spec:
  type: NodePort
  selector:
    app: test-30080
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# Service sur 30081
cat > /tmp/test-30081.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-30081
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-30081
  template:
    metadata:
      labels:
        app: test-30081
    spec:
      containers:
      - name: httpd
        image: httpd:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-30081
spec:
  type: NodePort
  selector:
    app: test-30081
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
EOF

kubectl apply -f /tmp/test-30080.yaml
kubectl apply -f /tmp/test-30081.yaml

# Créer un namespace pour les démos
kubectl create namespace pwd-demo

echo "✅ Kubernetes initialisé avec succès!"
echo "   - API: port 6443"
echo "   - Services test: ports 30080, 30081"
echo "   - Tous les NodePorts: 30000-32767 disponibles"