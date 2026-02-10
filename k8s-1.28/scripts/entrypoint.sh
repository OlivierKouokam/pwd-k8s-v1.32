#!/bin/bash
# entrypoint.sh - Version Complète avec vérification containerd

set -e

echo "========================================"
echo "🚀 EazyTraining K8s Mono - Version Complète"
echo "========================================"
echo "Kubernetes: ${K8S_VERSION}"
echo "Containerd: ${CONTAINERD_VERSION}"
echo "Outils: kubectl, git, curl, vim, k9s, yq, ..."
echo "========================================"

# Vérification des outils installés
echo "🔧 Vérification des outils..."
command -v kubectl && kubectl version --client
command -v kubeadm && kubeadm version
command -v kubelet && kubelet --version
command -v containerd && containerd --version
command -v git && git --version
command -v curl && curl --version
command -v vim && vim --version | head -1
command -v k9s && k9s version

# Vérification et configuration de containerd
echo "🔧 Vérification de containerd..."
if [ ! -f /usr/local/bin/containerd ]; then
    echo "❌ containerd non trouvé, installation..."
    if [ -f /usr/local/bin/install-containerd.sh ]; then
        /usr/local/bin/install-containerd.sh
    fi
fi

if [ ! -f /etc/containerd/config.toml ]; then
    echo "⚙️  Génération de la config containerd..."
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml 2>/dev/null || true
    if [ -f /etc/containerd/config.toml ]; then
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    fi
fi

# Démarrer systemd comme PID 1
if [ "$(basename $(readlink -f /proc/1/exe))" != "systemd" ]; then
    echo "🔄 Lancement de systemd..."
    exec /lib/systemd/systemd --system --unit=multi-user.target
fi

# Démarrer les services
echo "⚙️  Démarrage des services système..."

# Activer le forwarding IP
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.bridge.bridge-nf-call-iptables=1
sysctl -w net.bridge.bridge-nf-call-ip6tables=1

# Démarrer containerd
systemctl start containerd

# Attendre containerd
echo "⏳ Attente de containerd..."
MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
    if [ -S /run/containerd/containerd.sock ] && containerd --version >/dev/null 2>&1; then
        echo "✅ containerd prêt (tentative $i/$MAX_RETRIES)"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        echo "❌ containerd n'a pas démarré après $MAX_RETRIES tentatives"
        journalctl -u containerd --no-pager -n 50 2>/dev/null || true
        exit 1
    fi
    sleep 2
done

# Démarrer kubelet
systemctl start kubelet

# Initialiser Kubernetes si nécessaire
if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "🔧 Initialisation de Kubernetes..."
    /usr/local/bin/init-k8s.sh
else
    echo "✅ Kubernetes déjà initialisé"
fi

# Attendre que l'API soit disponible
echo "⏳ Attente de l'API Kubernetes..."
for i in {1..30}; do
    if kubectl get nodes >/dev/null 2>&1; then
        echo "✅ API Kubernetes disponible"
        break
    fi
    echo "   Tentative $i/30..."
    sleep 10
done

# Afficher les informations
echo ""
echo "========================================"
echo "✅ PWD K8s Mono PRÊT À L'EMPLOI"
echo "========================================"
echo ""
echo "📦 OUTILS DISPONIBLES:"
echo "   • kubectl, kubeadm, kubelet"
echo "   • git, curl, wget, vim, nano"
echo "   • k9s (TUI Kubernetes)"
echo "   • yq, jq (JSON/YAML processing)"
echo "   • helm, istio (via /usr/local/bin/tools/)"
echo ""
echo "🌐 PORTS EXPOSÉS:"
echo "   • Kubernetes API: 6443"
echo "   • NodePorts: 30000-32767 (TOUS les ports)"
echo "   • Services système: 80, 443, 10250, etc."
echo ""
echo "🔗 ACCÈS:"
echo "   Dans le conteneur:"
echo "     kubectl get nodes"
echo "     kubectl get pods -A"
echo ""
echo "   Depuis l'hôte:"
echo "     docker exec -it <container> kubectl get nodes"
echo "     docker cp <container>:/kubeconfig ."
echo ""
echo "   Depuis PWD web:"
echo "     Ouvrir n'importe quel port 30000-32767"
echo ""
echo "🧪 Service de test:"
echo "     Port: 30080 (nginx)"
echo "     URL: http://<pwd-host>:30080"
echo "========================================"

# Lancer k9s en arrière-plan pour ceux qui veulent une interface
echo "🎮 Interface k9s disponible: exécutez 'k9s' dans le conteneur"

# Garder le conteneur en vie
echo "🔄 En cours d'exécution..."
tail -f /dev/null