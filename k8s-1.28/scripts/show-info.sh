#!/bin/bash
# show-info.sh

echo ""
echo "========================================"
echo "📊 INFORMATIONS DU CLUSTER"
echo "========================================"
echo ""

# Informations du cluster
echo "🔗 Kubernetes:"
kubectl cluster-info 2>/dev/null || echo "  Non disponible"

echo ""
echo "📦 Nodes:"
kubectl get nodes 2>/dev/null || echo "  Non disponible"

echo ""
echo "🐳 Pods système:"
kubectl get pods -n kube-system 2>/dev/null | head -5 || echo "  Non disponible"

echo ""
echo "🌐 Services:"
kubectl get svc -A 2>/dev/null | grep -E "(pwd-nginx|kubernetes)" || echo "  Non disponible"

echo ""
echo "========================================"
echo "🎯 POUR PWD"
echo "========================================"
echo ""
echo "🔗 Kubeconfig:"
echo "   docker cp <container_id>:/kubeconfig ."
echo ""
echo "🌐 Services exposés:"
echo "   - Kubernetes API: port 6443"
echo "   - Service test: port 30080"
echo "   - Kubelet: ports 10250, 10255"
echo ""
echo "📋 Commandes utiles:"
echo "   docker exec <container_id> kubectl get nodes"
echo "   docker exec <container_id> kubectl get pods -A"
echo ""
echo "========================================"