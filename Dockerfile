# ==============================================================================
# Dockerfile Kubernetes v1.32 sur Ubuntu 22.04 
# Architecture basée sur votre design intelligent
# ==============================================================================

FROM ubuntu:22.04

LABEL maintainer="K8s v1.32 Ubuntu Migration" \
      version="1.32.0" \
      description="Kubernetes v1.32 mono-node cluster - Ubuntu 22.04" \
      base.image="ubuntu:22.04" \
      kubernetes.version="1.32"

# Variables d'environnement
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    K8S_VERSION=1.32 \
    UBUNTU_VERSION=22.04 \
    CONTAINERD_VERSION=1.7.22 \
    POD_NETWORK_CIDR=10.244.0.0/16 \
    SERVICE_NETWORK_CIDR=10.96.0.0/12 \
    CLUSTER_DNS=10.96.0.10

# ==============================================================================
# ÉTAPE 1: Installation des paquets de base
# ==============================================================================

RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    dbus \
    init \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    wget \
    git \
    net-tools \
    iproute2 \
    iptables \
    iputils-ping \
    vim \
    nano \
    htop \
    jq \
    tree \
    bash-completion \
    sudo \
    psmisc \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Configuration systemd pour conteneurs (reprise de votre logique)
RUN systemctl set-default multi-user.target && \
    systemctl mask dev-hugepages.mount sys-fs-fuse-connections.mount && \
    cd /lib/systemd/system/sysinit.target.wants/ && \
    ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1 || true && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
        /etc/systemd/system/*.wants/* \
        /lib/systemd/system/local-fs.target.wants/* \
        /lib/systemd/system/sockets.target.wants/*udev* \
        /lib/systemd/system/sockets.target.wants/*initctl* \
        /lib/systemd/system/basic.target.wants/* \
        /lib/systemd/system/anaconda.target.wants/* \
        /lib/systemd/system/plymouth* \
        /lib/systemd/system/systemd-update-utmp* || true

# ==============================================================================
# ÉTAPE 2: Installation de containerd (remplace Docker pour K8s v1.32)
# ==============================================================================

# Installation de containerd depuis les repos officiels
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y containerd.io docker-ce docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Configuration containerd adaptée à votre architecture
RUN mkdir -p /etc/containerd && \
    containerd config default > /etc/containerd/config.toml && \
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# ==============================================================================
# ÉTAPE 3: Installation des outils Kubernetes v1.32
# ==============================================================================

# Ajout du repository Kubernetes v1.32
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubelet kubeadm kubectl && \
    apt-mark hold kubelet kubeadm kubectl && \
    rm -rf /var/lib/apt/lists/*

# Installation d'outils supplémentaires (équivalents à votre setup)
RUN curl -Lf -o /usr/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 && \
    curl -Lf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m) && \
    chmod +x /usr/bin/jq /usr/bin/docker-compose

# ==============================================================================
# ÉTAPE 4: Copie et adaptation de vos fichiers de configuration
# ==============================================================================

# Copie du systemctl personnalisé (votre invention géniale !)
COPY ./systemctl /usr/bin/systemctl
RUN chmod +x /usr/bin/systemctl

# Configuration kubelet adaptée à v1.32
COPY ./kubelet.env.v132 /etc/systemd/system/kubelet.env
COPY ./kubelet.service.v132 /etc/systemd/system/kubelet.service

# Configuration containerd adaptée (remplace daemon.json)
COPY ./containerd.config.v132 /etc/containerd/config.toml

# Configuration Docker pour DinD (gardé pour compatibilité)
COPY ./daemon.json.v132 /etc/docker/daemon.json
COPY ./docker.service.v132 /usr/lib/systemd/system/docker.service

# Script wrapper kubeadm adapté à v1.32
COPY ./wrapkubeadm.v132.sh /usr/local/bin/kubeadm
RUN chmod +x /usr/local/bin/kubeadm

# Fichiers de configuration système
COPY ./tokens.csv /etc/pki/tokens.csv
COPY ./resolv.conf.override /etc/
COPY ./motd.v132 /etc/motd

# ==============================================================================
# ÉTAPE 5: Configuration du système
# ==============================================================================

# Configuration modules kernel pour Kubernetes
RUN echo 'overlay' >> /etc/modules-load.d/k8s.conf && \
    echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf

# Configuration sysctl pour Kubernetes v1.32
RUN echo 'net.bridge.bridge-nf-call-iptables  = 1' > /etc/sysctl.d/k8s.conf && \
    echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf && \
    echo 'net.ipv4.ip_forward                 = 1' >> /etc/sysctl.d/k8s.conf

# Configuration bash (reprise de votre logique)
RUN echo $'cat /etc/motd \n\
export PS1="[\h \\W]$ "' >> /root/.bash_profile

# Configuration kubectl 
RUN mkdir -p /root/.kube && \
    echo 'source <(kubectl completion bash)' >> /root/.bashrc && \
    echo 'alias k=kubectl' >> /root/.bashrc && \
    echo 'complete -F __start_kubectl k' >> /root/.bashrc

# Génération machine-id unique (repris de votre wrapper)
RUN rm -f /etc/machine-id

# Volume pour kubelet (conservé de votre architecture)
VOLUME ["/var/lib/kubelet"]

WORKDIR /root

# CMD adapté avec containerd au lieu de Docker
CMD mount --make-shared / && \
    systemctl start containerd && \
    systemctl start docker && \
    systemctl start kubelet && \
    while true; do bash -l; done

# ==============================================================================
# PORTS EXPOSÉS (mis à jour pour K8s v1.32)
# ==============================================================================
EXPOSE 6443 2379 2380 10250 10251 10252 10257 10259 30000-32767
