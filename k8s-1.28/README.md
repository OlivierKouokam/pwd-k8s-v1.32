# PWD K8s Mono - Version Complète

## Fonctionnalités
- ✅ Kubernetes v1.28.0
- ✅ Containerd comme runtime
- ✅ Tous les outils: kubectl, git, curl, vim, k9s, yq, jq
- ✅ Tous les ports NodePort exposés (30000-32767)
- ✅ Auto-démarrage du cluster
- ✅ Service de test sur ports 30080 et 30081

## Utilisation sur PWD
```bash
# Lancer le conteneur
docker run -d --privileged --name pwd-k8s eazytraining/k8s-mono:complete

# Attendre 2-3 minutes que K8s démarre
# Vérifier les logs
docker logs -f pwd-k8s

# Utiliser kubectl depuis l'hôte
docker exec pwd-k8s kubectl get nodes
docker exec pwd-k8s kubectl get pods -A

# Récupérer le kubeconfig
docker cp pwd-k8s:/kubeconfig .
kubectl --kubeconfig=kubeconfig get nodes