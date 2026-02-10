# Dockerfile.pwd-k8s-corrected
FROM kindest/node:v1.35.0

# Installer kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Copier le script d'initialisation
COPY init-k8s.sh /init-k8s.sh
RUN chmod +x /init-k8s.sh

# Exposer les ports pour PWD
EXPOSE 80 443 6443 30000-32767

# Utiliser l'entrypoint original de Kind + notre script
ENTRYPOINT ["/usr/local/bin/entrypoint", "/init-k8s.sh"]