#!/bin/bash

echo "Ì¥ß Construction de l'image Kubernetes v1.32 Ubuntu 22.04..."

# Cr√©er les fichiers de configuration
mkdir -p k8s-v132-build
cd k8s-v132-build

# Le script cr√©era automatiquement tous les fichiers n√©cessaires
# dans le r√©pertoire de build

# Construction de l'image
docker build -t k8s-ubuntu:v1.32 -t k8s-ubuntu:latest .

echo "‚úÖ Image construite : k8s-ubuntu:v1.32"
echo "Ì∫Ä D√©marrage : docker run -d --privileged --name k8s-cluster k8s-ubuntu:v1.32"
