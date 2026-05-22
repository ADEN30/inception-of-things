# Simulation d'une chaîne Dev → Staging → Prod

## Contexte

Reproduire avec Kubernetes le workflow actuel :

| Environnement actuel | Équivalent Kubernetes |
|----------------------|-----------------------|
| Serveur dev personnel | namespace `dev` |
| Serveur dev-global | namespace `staging` |
| Serveur préprod client | namespace `preprod` |
| Serveur prod | namespace `prod` |

---

## Architecture cible

```
Repo GitHub (inception-of-things)
├── manifests/
│   ├── dev/        ← Argo CD sync automatique → namespace dev
│   ├── staging/    ← Argo CD sync manuel      → namespace staging
│   └── prod/       ← Argo CD sync manuel      → namespace prod
```

---

## Workflow Git

```
Développeur push sur main
        │
        ▼
manifests/dev/deployment.yaml  →  Auto-déployé en dev
        │
        │  Tu valides : "ça marche"
        ▼
manifests/staging/deployment.yaml  →  Sync manuel dans Argo CD  →  staging
        │
        │  Client valide
        ▼
manifests/prod/deployment.yaml  →  Sync manuel dans Argo CD  →  prod
```

---

## Ce qu'il faut construire

### 1. Restructurer les manifests

```
manifests/
├── dev/
│   └── deployment.yaml   (image: wil42/playground:v1, replicas: 1)
├── staging/
│   └── deployment.yaml   (image: wil42/playground:v1, replicas: 1)
└── prod/
    └── deployment.yaml   (image: wil42/playground:v1, replicas: 2)
```

### 2. Créer 3 Argo CD Applications

- `playground-dev` : pointe sur `manifests/dev/`, auto-sync activé
- `playground-staging` : pointe sur `manifests/staging/`, sync manuel
- `playground-prod` : pointe sur `manifests/prod/`, sync manuel

### 3. Mettre à jour les namespaces

Ajouter `staging` et `preprod` dans `p3/confs/namespace.yaml`

---

## Simulation d'une mise en production

```bash
# 1. Dev change l'image en v2 dans manifests/dev/
# 2. Push → Argo CD déploie automatiquement en dev
curl http://localhost:8888/   # → v2 en dev

# 3. Validation dev OK → on promeut en staging
#    (changer manifests/staging/deployment.yaml → v2)
#    Sync manuel dans Argo CD
kubectl argo-cd app sync playground-staging

# 4. Client valide → on promeut en prod
#    (changer manifests/prod/deployment.yaml → v2)
#    Sync manuel dans Argo CD
kubectl argo-cd app sync playground-prod
```

---

## Mapping avec Odoo en production

| Étape | Kubernetes | Odoo |
|-------|-----------|------|
| Dev push | `manifests/dev/` mis à jour | Branche feature/ |
| Merge dev-global | `manifests/staging/` mis à jour | Merge sur develop |
| Validation client | Sync Argo CD staging | Tests préprod |
| Mise en prod | Sync Argo CD prod | Déploiement prod |
| Rollback | `kubectl rollout undo` | Rollback manuel |
