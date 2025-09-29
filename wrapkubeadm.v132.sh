#!/bin/bash
# ==============================================================================
# Wrapper kubeadm pour Kubernetes v1.32 en environnement conteneurisé
# Adapté pour Ubuntu 22.04 avec containerd
# ==============================================================================

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================================================
# Génération d'un machine-id unique si absent
# ==============================================================================
if [ ! -f /etc/machine-id ] || [ ! -s /etc/machine-id ]; then
    log_info "Génération d'un machine-id unique..."
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id
    log_success "Machine-id généré: $(cat /etc/machine-id)"
fi

# ==============================================================================
# Vérification des prérequis
# ==============================================================================
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Vérifier containerd
    if ! pgrep containerd > /dev/null; then
        log_error "containerd n'est pas en cours d'exécution"
        log_info "Démarrage de containerd..."
        containerd > /var/log/containerd.log 2>&1 &
        sleep 3
        if ! pgrep containerd > /dev/null; then
            log_error "Impossible de démarrer containerd"
            exit 1
        fi
    fi
    log_success "containerd est actif"
    
    # Vérifier les modules kernel
    modprobe overlay 2>/dev/null || log_warn "Module overlay non chargé"
    modprobe br_netfilter 2>/dev/null || log_warn "Module br_netfilter non chargé"
    
    # Appliquer les paramètres sysctl
    sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>&1 || true
    sysctl -w net.bridge.bridge-nf-call-ip6tables=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
    
    log_success "Prérequis vérifiés"
}

# ==============================================================================
# Fonction principale d'initialisation
# ==============================================================================
if [ "$1" = "init" ]; then
    log_info "=== Initialisation du cluster Kubernetes v1.32 ==="
    
    check_prerequisites
    
    # Extraire les arguments de l'utilisateur
    USER_ARGS=("${@:2}")
    
    # Détecter l'adresse IP si non spécifiée
    API_SERVER_ADDR=""
    for i in "${!USER_ARGS[@]}"; do
        if [[ "${USER_ARGS[$i]}" == "--apiserver-advertise-address" ]]; then
            API_SERVER_ADDR="${USER_ARGS[$((i+1))]}"
            break
        fi
    done
    
    if [ -z "$API_SERVER_ADDR" ]; then
        API_SERVER_ADDR=$(hostname -i | awk '{print $1}')
        log_info "Adresse API Server détectée: $API_SERVER_ADDR"
    fi
    
    # Construire la commande kubeadm
    log_info "Lancement de kubeadm init..."
    
    # Options de base pour environnement conteneurisé
    KUBEADM_OPTS=(
        "--apiserver-advertise-address=${API_SERVER_ADDR}"
        "--pod-network-cidr=10.244.0.0/16"
        "--service-cidr=10.96.0.0/12"
        "--cri-socket=unix:///var/run/containerd/containerd.sock"
        "--ignore-preflight-errors=NumCPU,Mem,SystemVerification,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables"
        "--v=5"
    )
    
    # Ajouter les arguments utilisateur qui ne sont pas déjà définis
    for arg in "${USER_ARGS[@]}"; do
        if [[ ! " ${KUBEADM_OPTS[@]} " =~ " ${arg} " ]]; then
            KUBEADM_OPTS+=("$arg")
        fi
    done
    
    # Exécuter kubeadm init
    log_info "Commande: /usr/bin/kubeadm init ${KUBEADM_OPTS[*]}"
    
    if /usr/bin/kubeadm init "${KUBEADM_OPTS[@]}"; then
        log_success "Cluster initialisé avec succès!"
        
        # Configuration kubectl automatique
        log_info "Configuration de kubectl..."
        mkdir -p $HOME/.kube
        cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config 2>/dev/null || true
        export KUBECONFIG=/etc/kubernetes/admin.conf
        
        log_success "kubectl configuré"
        
        # Installation de Flannel CNI
        log_info "Installation du CNI Flannel..."
        sleep 5
        
        if kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml 2>/dev/null; then
            log_success "Flannel CNI installé"
        else
            log_warn "Échec de l'installation automatique de Flannel"
            log_info "Vous pouvez l'installer manuellement avec:"
            echo "  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
        fi
        
        # Permettre le scheduling sur le nœud master
        log_info "Autorisation du scheduling sur le nœud master..."
        kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || \
        kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true
        
        log_success "Configuration terminée!"
        echo ""
        echo "=========================================="
        echo " Cluster Kubernetes v1.32 opérationnel! "
        echo "=========================================="
        echo ""
        echo "Vérifiez l'état avec:"
        echo "  kubectl get nodes"
        echo "  kubectl get pods -A"
        echo ""
        
    else
        log_error "Échec de l'initialisation du cluster"
        exit 1
    fi

# ==============================================================================
# Autres commandes kubeadm (reset, join, etc.)
# ==============================================================================
elif [ "$1" = "reset" ]; then
    log_info "Réinitialisation du cluster..."
    /usr/bin/kubeadm reset --force --cri-socket=unix:///var/run/containerd/containerd.sock
    rm -rf $HOME/.kube
    log_success "Cluster réinitialisé"
    
elif [ "$1" = "join" ]; then
    log_info "Jonction au cluster..."
    check_prerequisites
    /usr/bin/kubeadm join "${@:2}" --cri-socket=unix:///var/run/containerd/containerd.sock
    
else
    # Pour toutes les autres commandes, passer directement à kubeadm
    /usr/bin/kubeadm "$@"
fi
