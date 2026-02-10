# tools/pwd-expose.sh
#!/bin/bash
echo "=== PWD Ports ==="
echo "K8s API: 6443"
echo "Services NodePort: 30000-32767"
echo "Test App: 30080"
echo ""
echo "Sur PWD web, cliquez sur 'OPEN PORT' et entrez le numéro"