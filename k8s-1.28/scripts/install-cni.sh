#!/bin/bash
# install-cni.sh

set -e

echo "🌐 Installation des plugins CNI..."

# Télécharger les plugins CNI
sudo mkdir -p /opt/cni/bin

curl -L "https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz" | \
  tar -C /opt/cni/bin -xz

echo "✅ Plugins CNI installés"