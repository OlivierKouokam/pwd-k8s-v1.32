#!/bin/bash
# install-k8s.sh

set -e

echo "📦 Installation des binaires Kubernetes ${K8S_VERSION}..."

# Télécharger les binaires
curl -L --remote-name-all \
  "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm" \
  "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl" \
  "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet"

# Rendre exécutables
chmod +x kubeadm kubectl kubelet

# Déplacer dans le PATH
mv kubeadm kubectl kubelet /usr/local/bin/

# Télécharger crictl
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz" | \
  tar -C /usr/local/bin -xz

chmod +x /usr/local/bin/crictl

echo "✅ Kubernetes installé"