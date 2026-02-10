# Dockerfile.pwd-k8s-complete
FROM ubuntu:22.04

# Variables d'environnement
ENV K8S_VERSION=v1.28.0
ENV CONTAINERD_VERSION=1.7.13
ENV RUNC_VERSION=1.1.12
ENV CNI_VERSION=1.4.0
ENV CRICTL_VERSION=1.29.0
ENV DEBIAN_FRONTEND=noninteractive

# 1. Installation de TOUS les outils nécessaires
RUN apt-get update && apt-get install -y \
    # Outils système
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    # Systemd et réseau
    systemd \
    systemd-sysv \
    systemd-container \
    iptables \
    iproute2 \
    ipset \
    iputils-ping \
    net-tools \
    dnsutils \
    socat \
    conntrack \
    conntrackd \
    ebtables \
    ethtool \
    kmod \
    nftables \
    # Sécurité
    libseccomp2 \
    apparmor \
    # Outils de développement
    git \
    vim \
    nano \
    jq \
    #yq \
    tree \
    htop \
    tmux \
    screen \
    # Compilation
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    # Autres
    unzip \
    zip \
    tar \
    bzip2 \
    gzip \
    lz4 \
    zstd \
    rsync \
    lsof \
    strace \
    tcpdump \
    netcat \
    telnet \
    openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 2. Installation de kubectl (version spécifique)
RUN curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/ \
    && kubectl version --client

# 3. Installation de kubeadm, kubelet
RUN curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm" \
    && curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet" \
    && chmod +x kubeadm kubelet \
    && mv kubeadm kubelet /usr/local/bin/

# 4. Installation de containerd
RUN curl -L "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz" \
    | tar -C /usr/local -xz \
    && curl -L "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64" \
    -o /usr/local/sbin/runc \
    && chmod +x /usr/local/sbin/runc

# 5. Installation de crictl
RUN curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz" \
    | tar -C /usr/local/bin -xz \
    && chmod +x /usr/local/bin/crictl

# 6. Installation des plugins CNI
RUN mkdir -p /opt/cni/bin && \
    curl -L "https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz" \
    | tar -C /opt/cni/bin -xz

# 7. Installation d'outils Kubernetes supplémentaires
RUN curl -L "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" \
    | tar -C /usr/local/bin -xz k9s \
    && chmod +x /usr/local/bin/k9s

RUN curl -L "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# 8. Création des répertoires
RUN mkdir -p \
    /etc/containerd \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubeadm \
    /var/log/kubernetes \
    /run/containerd \
    /root/.kube

# 9. Copie des scripts
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# 10. Configuration systemd
RUN systemctl mask \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    systemd-remount-fs.service \
    getty.target \
    console-getty.service

# 11. Services systemd avec containerd.service
COPY config/containerd.service /etc/systemd/system/containerd.service
COPY config/kubelet.service /etc/systemd/system/kubelet.service
COPY config/init-k8s.service /etc/systemd/system/init-k8s.service

RUN systemctl enable containerd kubelet init-k8s
# RUN systemctl enable containerd kubelet init-k8s && \
#     # Configurer containerd
#     containerd config default > /etc/containerd/config.toml && \
#     # Remplacer par notre config personnalisée
#     cp config/containerd.toml /etc/containerd/config.toml && \
#     # Configurer cgroup driver systemd
#     sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# 12. Fichiers de configuration
COPY config/containerd.toml /etc/containerd/config.toml
COPY config/10-flannel.conflist /etc/cni/net.d/10-flannel.conflist
COPY config/kubeadm-config.yaml /etc/kubernetes/kubeadm-config.yaml
COPY config/kubelet-config.yaml /var/lib/kubelet/config.yaml

# 13. Scripts utiles
COPY tools/ /usr/local/bin/tools/
RUN chmod +x /usr/local/bin/tools/*

# 14. Exposer TOUS les ports NodePort (30000-32767) + autres
EXPOSE 80 443 6443 2379-2380 10250 10255 10256 30000-32767

# 15. Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5m --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# 16. Point d'entrée
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]