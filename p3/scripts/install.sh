#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# Vagrant copies the script to /tmp — use the shared folder path instead
if [ -d /vagrant/confs ]; then
    CONFS_DIR="/vagrant/confs"
else
    CONFS_DIR="$SCRIPT_DIR/../confs"
fi

# Install to /usr/local/bin if writable (root), otherwise ~/.local/bin
if [ "$(id -u)" = "0" ] || [ -w /usr/local/bin ]; then
    BIN_DIR="/usr/local/bin"
else
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
fi
export PATH="$BIN_DIR:$PATH"

# Install k3d
if ! command -v k3d &>/dev/null; then
    echo "Installing k3d..."
    if [ "$BIN_DIR" = "/usr/local/bin" ]; then
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    else
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
            | USE_SUDO=false K3D_INSTALL_DIR="$BIN_DIR" bash
    fi
fi

# Install kubectl
if ! command -v kubectl &>/dev/null; then
    echo "Installing kubectl..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl "$BIN_DIR/kubectl"
fi

# Create cluster
if ! k3d cluster list 2>/dev/null | grep -q "iot-cluster"; then
    echo "Creating k3d cluster..."
    k3d cluster create iot-cluster \
        --port "8888:8888@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0" \
        --wait
fi

# Create namespaces
kubectl apply -f "$CONFS_DIR/namespace.yaml"

# Install Argo CD
echo "Installing Argo CD..."
kubectl apply -n argocd --server-side --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD
echo "Waiting for Argo CD..."
kubectl wait --for=condition=established --timeout=120s crd/applications.argoproj.io
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Apply ArgoCD Application
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"

# Copy kubeconfig for vagrant user if running as root
if [ "$(id -u)" = "0" ] && [ -d /home/vagrant ]; then
    mkdir -p /home/vagrant/.kube
    k3d kubeconfig get iot-cluster > /home/vagrant/.kube/config
    chown -R vagrant:vagrant /home/vagrant/.kube
fi

echo ""
echo "Done! Argo CD will sync the app in ~1 minute."
echo "App:      http://localhost:8888/"
echo ""
echo "Argo CD admin password:"
kubectl get secret argocd-initial-admin-secret -n argocd \
    -o jsonpath="{.data.password}" | base64 -d
echo ""
