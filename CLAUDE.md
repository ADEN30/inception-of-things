# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Inception-of-Things (IoT) is a 42 school system administration project introducing Kubernetes via K3s, K3d, and Argo CD. The entire project runs inside virtual machines. There is no application code to build or test — only infrastructure configuration files and provisioning scripts.

## Repository Structure

```
p1/          # Part 1: K3s + Vagrant (2-node cluster)
  Vagrantfile
  scripts/   # Shell provisioning scripts
  confs/     # K8s/K3s configuration files
p2/          # Part 2: K3s + Vagrant (single node, 3 apps via Ingress)
  Vagrantfile
  scripts/
  confs/
p3/          # Part 3: K3d + Argo CD (no Vagrant)
  scripts/   # install.sh and setup scripts
  confs/     # K8s manifests, Argo CD app definitions
bonus/       # Bonus: Part 3 + GitLab (namespace: gitlab)
  Vagrantfile
  scripts/
  confs/
```

## Key Commands

### Vagrant (p1, p2, bonus)
```bash
vagrant up          # Start all VMs and run provisioners
vagrant halt        # Stop VMs
vagrant destroy -f  # Destroy VMs
vagrant ssh <name>  # SSH into a VM (e.g., vagrant ssh agalletS)
vagrant status      # Show VM states
```

### Inside the VM — K3s / kubectl
```bash
kubectl get nodes -o wide
kubectl get all -n <namespace>
kubectl get pods -n kube-system
kubectl describe pod <name>
kubectl logs <pod>
```

### K3d (p3)
```bash
k3d cluster create <name>
k3d cluster list
k3d cluster delete <name>
```

### Argo CD
```bash
kubectl get ns                          # Verify argocd and dev namespaces exist
kubectl get pods -n argocd
kubectl get pods -n dev
curl http://localhost:8888/             # Test deployed app version
```

## Architecture by Part

### Part 1 — Two-node K3s cluster
- **agalletS** (Server): IP `192.168.56.110`, K3s in controller mode, kubectl installed
- **agalletSW** (ServerWorker): IP `192.168.56.111`, K3s in agent mode
- VMs: 1 CPU, 512–1024 MB RAM, SSH passwordless
- The worker joins via the server's node token (`/var/lib/rancher/k3s/server/node-token`)

### Part 2 — Single-node K3s with Ingress routing
- **agalletS**: IP `192.168.56.110`, K3s server mode
- Three apps, routed by HTTP `Host` header via K3s built-in Traefik Ingress:
  - `app1.com` → app-one (1 replica)
  - `app2.com` → app-two (3 replicas)
  - default (any other HOST) → app-three (1 replica)
- Test routing: `curl -H "Host:app1.com" 192.168.56.110`

### Part 3 — K3d + Argo CD GitOps loop
- No Vagrant; everything runs in Docker via K3d on the host VM
- Must provide a `scripts/install.sh` that installs Docker, K3d, kubectl, and any other dependencies
- Two namespaces: `argocd` and `dev`
- Argo CD watches a **public GitHub repository** (repo name must include a team member's login) for manifests in a `manifests/` path
- App deployed into `dev` namespace; must have `v1` and `v2` Docker image tags (default reference: `wil42/playground`, port 8888)
- Switching versions: update image tag in GitHub repo → Argo CD auto-syncs → verify with `curl http://localhost:8888/`

### Bonus — GitLab added to Part 3
- All Part 3 requirements remain, but Argo CD syncs from a **local GitLab** instance instead of GitHub
- Add a `gitlab` namespace; deploy GitLab via Helm or manifest
- GitLab must run locally and integrate with the K3d cluster

## Critical Constraints

- Machine hostnames must follow the pattern `<login>S` and `<login>SW` (e.g., `agalletS`, `agalletSW`)
- IPs are fixed: `192.168.56.110` (Server) and `192.168.56.111` (ServerWorker)
- Use the **latest stable** Linux distribution and K3s/K3d versions
- Vagrantfiles must follow modern practices (Vagrant.configure(2), no deprecated options)
- Scripts go in `scripts/`, K8s manifests and config files go in `confs/`
- The Ingress resource must be present but is not shown to evaluators in screenshots — be prepared to demo it live
- Evaluation runs on the evaluator's machine, so scripts must be fully automated and idempotent
