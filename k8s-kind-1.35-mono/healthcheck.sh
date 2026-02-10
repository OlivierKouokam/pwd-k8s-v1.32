#!/bin/bash
# healthcheck.sh

# Vérification périodique de la santé
while true; do
    # Vérifier l'API
    if ! kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes >/dev/null 2>&1; then
        echo "❌ API Kubernetes inaccessible, redémarrage de kubelet..."
        systemctl restart kubelet
        sleep 30
    fi
    
    # Vérifier les pods système
    CRASHED_PODS=$(kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -n kube-system --field-selector=status.phase!=Running 2>/dev/null | wc -l)
    if [ "$CRASHED_PODS" -gt 1 ]; then
        echo "⚠️  Des pods système sont en erreur"
    fi
    
    # Vérifier l'espace disque
    DISK_USAGE=$(df /var/lib/docker --output=pcent | tail -1 | tr -d '% ')
    if [ "$DISK_USAGE" -gt 80 ]; then
        echo "⚠️  Espace disque faible: ${DISK_USAGE}%"
    fi
    
    sleep 60
done