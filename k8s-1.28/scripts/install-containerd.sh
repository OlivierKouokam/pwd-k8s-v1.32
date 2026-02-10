#!/bin/bash
# install-containerd.sh (version corrigée)

set -e

echo "🐳 Installation de containerd ${CONTAINERD_VERSION}..."

# Télécharger containerd
curl -fsSL "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz" | \
    tar -C /usr/local -xz

# Télécharger runc
curl -fsSL "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64" \
    -o /usr/local/sbin/runc && \
    chmod +x /usr/local/sbin/runc

# Créer les répertoires
mkdir -p /etc/containerd /run/containerd

# Générer config par défaut
containerd config default > /etc/containerd/config.toml

# Modifier pour utiliser systemd cgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Désactiver apparmor dans containerd pour compatibilité conteneur
sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\]/a\  disable_apparmor = true' /etc/containerd/config.toml

echo "✅ containerd installé et configuré"