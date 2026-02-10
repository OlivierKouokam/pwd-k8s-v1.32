#!/bin/bash
# healthcheck.sh

# Vérifier si l'API Kubernetes répond
if kubectl cluster-info >/dev/null 2>&1; then
    # Vérifier si les pods système sont en cours d'exécution
    RUNNING_PODS=$(kubectl get pods -n kube-system --field-selector=status.phase=Running -o name | wc -l)
    if [ "$RUNNING_PODS" -ge 3 ]; then
        exit 0  # Santé OK
    fi
fi

exit 1  # Santé KO