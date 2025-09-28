#!/bin/bash 
# Wrapper kubeadm adapté pour Kubernetes v1.32 sur Ubuntu 22.04
# Basé sur votre architecture mais modernisé

set -o pipefail
set -o errtrace

# Configuration pour K8s v1.32
apiserver_static_pod="/etc/kubernetes/manifests/kube-apiserver.yaml"
scheduler_static_pod="/etc/kubernetes/manifests/kube-scheduler.yaml"
controller_static_pod="/etc/kubernetes/manifests/kube-controller-manager.yaml"

# Filtres jq adaptés pour v1.32
apiserver_token_auth='.spec.containers[0].command|=map(select(startswith("--token-auth-file")|not))+["--token-auth-file=/etc/pki/tokens.csv"]'
apiserver_anonymous_auth='.spec.containers[0].command|=map(select(startswith("--anonymous-auth")|not))+["--anonymous-auth=true"]'

function dind::proxy-cidr-and-no-conntrack-v132 {
    # Adaptation pour les nouvelles versions de kube-proxy
    cluster_cidr="$(ip addr show docker0 2>/dev/null | grep -w inet | awk '{ print $2; }' || echo '10.244.0.0/16')"
    echo ".spec.template.spec.containers[0].command |= .+ [\"--cluster-cidr=${cluster_cidr}\", \"--proxy-mode=iptables\"]"
}

function dind::add-route-v132 {
    # Ajouter des routes pour les services K8s v1.32
    ip route add 10.96.0.0/16 dev eth0 2>/dev/null || true
    ip route add 10.244.0.0/16 dev docker0 2>/dev/null || true
}

function dind::join-filters {
    local IFS="|"
    echo "$*"
}

function dind::frob-apiserver-v132 {
    local -a filters=("${apiserver_token_auth}" "${apiserver_anonymous_auth}")
    dind::frob-file "${apiserver_static_pod}" "${filters[@]}"
}

function dind::frob-file {
    local path_base="$1"
    shift
    local filter="$(dind::join-filters "$@")"
    
    if [[ -f "${path_base}" ]]; then
        # Utilisation directe de jq pour les fichiers YAML (K8s v1.32 utilise YAML par défaut)
        local tmp_file=$(mktemp)
        cat "${path_base}" | jq "${filter}" > "${tmp_file}" 2>/dev/null || {
            # Si jq échoue sur YAML, convertir d'abord
            kubectl convert -f "${path_base}" --local -o json 2>/dev/null | jq "${filter}" > "${tmp_file}"
            kubectl convert -f "${tmp_file}" --local -o yaml 2>/dev/null > "${path_base}"
            rm -f "${tmp_file}"
            return $?
        }
        mv "${tmp_file}" "${path_base}"
    else
        echo "${path_base} not found" >&2
        return 1
    fi
}

function dind::frob-proxy-v132 {
    # Adaptation pour kube-proxy dans K8s v1.32
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if KUBECONFIG=/etc/kubernetes/admin.conf kubectl get daemonset kube-proxy -n kube-system >/dev/null 2>&1; then
            break
        fi
        echo "Waiting for kube-proxy daemonset... (attempt $((++attempt))/$max_attempts)"
        sleep 2
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        echo "Warning: kube-proxy daemonset not found, skipping proxy configuration"
        return 0
    fi
    
    # Mise à jour de la configuration kube-proxy
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system get ds kube-proxy -o json | \
        jq "$(dind::proxy-cidr-and-no-conntrack-v132)" | \
        KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f - || true
    
    # Redémarrage des pods kube-proxy
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system delete pods -l k8s-app=kube-proxy --force --grace-period=0 || true
}

function dind::wait-for-apiserver-v132 {
    echo -n "Waiting for API server to startup (K8s v1.32)"
    local url="https://localhost:6443/api"
    local n=120  # Plus de temps pour v1.32
    
    while true; do
        if curl -k -s "${url}" >&/dev/null; then
            echo " [OK]"
            break
        fi
        if ((--n == 0)); then
            echo ""
            echo "Error: timed out waiting for apiserver to become available" >&2
            return 1
        fi
        echo -n "."
        sleep 1
    done
}

function dind::install-cni-v132 {
    echo "Installing CNI plugin for K8s v1.32..."
    
    # Installation Flannel (compatible v1.32)
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml || {
        echo "Warning: Failed to install Flannel, trying Calico..."
        KUBECONFIG=/etc/kubernetes/admin.conf kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/tigera-operator.yaml || true
        
        # Configuration Calico avec le bon CIDR
        cat <<EOF | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF
    }
}

function dind::frob-cluster-v132 {
    echo "Configuring cluster for K8s v1.32..."
    dind::frob-apiserver-v132 || echo "Warning: Failed to configure apiserver"
    dind::wait-for-apiserver-v132
    
    # Installation du CNI
    dind::install-cni-v132
    
    # Configuration proxy
    dind::frob-proxy-v132
    
    # Configuration des routes
    dind::add-route-v132
    
    echo "Cluster configuration completed!"
}

# Génération machine-id unique si nécessaire
if [[ ! -f /etc/machine-id ]]; then
    rm -f /etc/machine-id
    if command -v systemd-machine-id-setup >/dev/null 2>&1; then
        systemd-machine-id-setup
    else
        # Fallback pour Ubuntu
        dbus-uuidgen --ensure=/etc/machine-id
    fi
fi

# Démarrage containerd si nécessaire
systemctl start containerd 2>/dev/null || true

# Traitement des commandes kubeadm
if [[ "$@" == "init"* || "$@" == "join"* ]]; then
    # Appel kubeadm avec paramètres et ignore des erreurs de préflight
    /usr/bin/kubeadm "$@" --ignore-preflight-errors=all,SystemVerification,Service-Docker
    exit_code=$?
    
    # Configuration post-init pour K8s v1.32
    if [[ "$@" == "init"* && $exit_code -eq 0 && ! "$@" == *"--help"* ]]; then
        # Attendre un peu que tout soit prêt
        sleep 10
        dind::frob-cluster-v132
    elif [[ "$@" == "join"* && $exit_code -eq 0 ]]; then
        dind::add-route-v132
    fi
    
    exit $exit_code
else
    # Appel kubeadm direct pour les autres commandes
    /usr/bin/kubeadm "$@"
fi
