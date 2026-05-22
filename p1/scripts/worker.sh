#!/bin/bash
set -e

apt-get update -qq && apt-get install -y -qq curl

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"
K3S_TOKEN="agallet42Token"

# Detect the interface bound to our private network IP
IFACE=$(ip -o addr | grep "$WORKER_IP" | awk '{print $2}')

export K3S_TOKEN="$K3S_TOKEN"
export K3S_URL="https://$SERVER_IP:6443"
export INSTALL_K3S_EXEC="agent \
  --node-ip=$WORKER_IP \
  --flannel-iface=$IFACE"

curl -sfL https://get.k3s.io | sh -

echo "K3s agent started."
