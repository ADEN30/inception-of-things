# Part 1 — Cluster K3s à 2 machines

## Le concept global

Un **cluster** c'est un groupe de machines qui travaillent ensemble comme si c'était une seule machine.

Dans le p1, on a créé un cluster avec 2 VMs :

```
Machine hôte (ton ordinateur)
├── VM agalletS   → 192.168.56.110  (le chef)
└── VM agalletSW  → 192.168.56.111  (l'exécutant)
```

---

## Les deux rôles

### Le Server (agalletS) — le chef de chantier

Il décide de tout :
- Quels pods tourner
- Sur quel node les placer
- Surveiller que tout fonctionne

C'est lui qui a `kubectl` — c'est l'outil de commande du cluster. Tu ne peux pas donner d'ordres depuis agalletSW.

### Le Worker (agalletSW) — l'ouvrier

Il exécute les ordres sans poser de questions :
- Il reçoit "lance ce pod"
- Il le lance
- Il rapporte son état au server

---

## Comment ils se parlent

Quand tu lances `vagrant up`, voici ce qui se passe dans l'ordre :

```
1. agalletS démarre
   └── installe K3s en mode "server"
   └── génère un token secret : "agallet42Token"
   └── attend les workers

2. agalletSW démarre
   └── installe K3s en mode "agent"
   └── dit au server : "je veux rejoindre, voici le token"
   └── le server accepte → le worker est dans le cluster
```

Tu peux vérifier avec `kubectl get nodes` depuis agalletS :

```
NAME        STATUS   ROLES                  AGE
agalletS    Ready    control-plane,master   5m
agalletSW   Ready    <none>                 3m
```

---

## Exemple concret : que se passe-t-il si agalletSW tombe ?

```
1. agalletSW crashe
2. Le server détecte que le worker ne répond plus
3. Les pods qui étaient sur agalletSW sont relancés sur agalletS
4. Le service continue de fonctionner
```

C'est ça la puissance d'un cluster : **la redondance**. Une machine peut tomber, les applications continuent.

---

## Exemple concret : déployer une application

Depuis agalletS, tu dis à Kubernetes :
```bash
kubectl create deployment monapp --image=nginx --replicas=3
```

Kubernetes décide tout seul où placer les 3 pods :
```
agalletS  → Pod 1
agalletSW → Pod 2
agalletSW → Pod 3
```

Il répartit la charge entre les deux machines automatiquement.

---

## Ce que tu as configuré dans les scripts

### scripts/server.sh
- Installe K3s en mode serveur
- Fixe l'IP à 192.168.56.110 pour que le worker sache où se connecter
- Précise l'interface réseau (`--flannel-iface`) pour que les pods communiquent sur le bon réseau

### scripts/worker.sh
- Installe K3s en mode agent
- Lui dit où est le server : `K3S_URL=https://192.168.56.110:6443`
- Lui donne le token pour s'authentifier : `K3S_TOKEN=agallet42Token`

---

## Résumé en une phrase

Le p1, c'est **deux VMs qui forment un seul cluster Kubernetes** : une machine fait les décisions, l'autre exécute — ensemble elles offrent de la redondance et de la répartition de charge.
