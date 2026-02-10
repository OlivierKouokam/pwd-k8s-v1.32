#!/bin/bash
# build.sh

set -e

echo "🔨 Construction de l'image PWD K8s Mono..."

# Nom de l'image
IMAGE_NAME="eazytraining/k8s-mono"
IMAGE_TAG="1.28"

# Construire l'image
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
docker rmi eazytraining/k8s-mono:1.18-test
docker tag ${IMAGE_NAME}:${IMAGE_TAG} eazytraining/k8s-mono:1.18-test

echo ""
echo "✅ Image construite:"
echo "   ${IMAGE_NAME}:${IMAGE_TAG}"
echo "   ${IMAGE_NAME}:latest"
echo ""
echo "🧪 Pour tester:"
echo "   docker run -d --privileged --name pwd-k8s-test ${IMAGE_NAME}:latest"
echo "   docker logs -f pwd-k8s-test"
echo ""
echo "📦 Pour publier:"
echo "   docker push ${IMAGE_NAME}:${IMAGE_TAG}"
echo "   docker push ${IMAGE_NAME}:latest"