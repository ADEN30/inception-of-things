#!/bin/bash
set -e

apt-get update -qq && apt-get install -y -qq curl

SERVER_IP="192.168.56.110"
IFACE=$(ip -o addr | grep "$SERVER_IP" | awk '{print $2}')

export K3S_TOKEN="agallet42Token"
export INSTALL_K3S_EXEC="server \
  --advertise-address=$SERVER_IP \
  --node-ip=$SERVER_IP \
  --flannel-iface=$IFACE"

curl -sfL https://get.k3s.io | sh -

echo "Waiting for K3s server to be ready..."
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  sleep 2
done

# Apply all manifests
kubectl apply -f /vagrant/confs/

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chmod 600 /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

echo "Done. Testing:"
kubectl get pods -o wide
kubectl get ingress
