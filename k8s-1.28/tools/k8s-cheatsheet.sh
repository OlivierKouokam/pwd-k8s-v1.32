# tools/k8s-cheatsheet.sh
#!/bin/bash
echo "=== K8s Cheatsheet ==="
echo "kubectl get nodes"
echo "kubectl get pods -A"
echo "kubectl get svc -A"
echo "kubectl describe node <node>"
echo "kubectl logs <pod> -n <namespace>"
echo "kubectl exec -it <pod> -- sh"
echo "kubectl port-forward svc/<service> 8080:80"