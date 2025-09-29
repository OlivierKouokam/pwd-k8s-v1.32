#!/bin/bash
set -e

echo ">>> Demarrage du conteneur Kubernetes v1.32..."

# Monter les systèmes de fichiers nécessaires
mount --make-shared / 2>/dev/null || true

# Créer les répertoires nécessaires
mkdir -p /var/run/containerd
mkdir -p /var/run/docker
mkdir -p /var/log

# ==============================================================================
# Démarrage de containerd
# ==============================================================================
echo ">>> Demarrage de containerd..."
rm -f /var/run/containerd/containerd.sock 2>/dev/null || true

containerd > /var/log/containerd.log 2>&1 &
CONTAINERD_PID=$!

# Attendre que containerd soit prêt
for i in {1..10}; do
    if [ -S /var/run/containerd/containerd.sock ]; then
        echo "[OK] containerd demarre (PID: $CONTAINERD_PID)"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "[ERREUR] Timeout - containerd ne demarre pas"
        cat /var/log/containerd.log
        exit 1
    fi
    sleep 1
done

# Vérifier que containerd répond
if ctr version > /dev/null 2>&1; then
    echo "[OK] containerd operationnel"
else
    echo "[WARN] containerd demarre mais ne repond pas encore"
fi

# ==============================================================================
# Démarrage de Docker
# ==============================================================================
echo ">>> Demarrage de Docker..."
rm -f /var/run/docker.sock 2>/dev/null || true
rm -f /var/run/docker.pid 2>/dev/null || true

# S'assurer que le groupe docker existe
groupadd -f docker 2>/dev/null || true

# Démarrer dockerd avec options explicites
dockerd \
    --host=unix:///var/run/docker.sock \
    --containerd=/var/run/containerd/containerd.sock \
    --storage-driver=overlay2 \
    --iptables=true \
    --ip-masq=true \
    > /var/log/dockerd.log 2>&1 &

DOCKER_PID=$!

# Attendre que Docker soit prêt
for i in {1..15}; do
    if docker info > /dev/null 2>&1; then
        echo "[OK] Docker demarre (PID: $DOCKER_PID)"
        docker version | grep "Server Version" || true
        break
    fi
    if [ $i -eq 15 ]; then
        echo "[WARN] Docker ne demarre pas - Ce n'est pas bloquant pour K8s"
        echo "       Containerd est suffisant pour Kubernetes v1.32"
        cat /var/log/dockerd.log | tail -20
        break
    fi
    sleep 1
done

# ==============================================================================
# Configuration de l'environnement
# ==============================================================================

# Configuration kubectl
export KUBECONFIG=/etc/kubernetes/admin.conf

# Charger les modules kernel
modprobe overlay 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true

# Appliquer les paramètres sysctl
sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>&1 || true
sysctl -w net.bridge.bridge-nf-call-ip6tables=1 >/dev/null 2>&1 || true
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true

# Afficher le MOTD
if [ -f /etc/motd ]; then
    cat /etc/motd
fi

echo ""
echo "=========================================="
echo "[OK] Services demarres - Conteneur pret!"
echo "=========================================="
echo ""
echo "Services actifs:"
echo "  - containerd: $(pgrep containerd > /dev/null && echo 'OK' || echo 'KO')"
echo "  - docker:     $(pgrep dockerd > /dev/null && echo 'OK' || echo 'KO (optionnel)')"
echo ""
echo "Pour initialiser le cluster Kubernetes :"
echo "  kubeadm init --apiserver-advertise-address \$(hostname -i) --pod-network-cidr=10.244.0.0/16"
echo ""
echo "Ou directement avec l'IP detectee:"
echo "  kubeadm init --apiserver-advertise-address $(hostname -i | awk '{print $1}') --pod-network-cidr=10.244.0.0/16"
echo ""

# Démarrer bash interactif
exec /bin/bash
