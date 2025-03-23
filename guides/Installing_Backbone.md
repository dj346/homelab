# Homelab Deployment Guide

## Table of Contents

- [Prerequisites](#prerequisites)
- [Fork the Repository](#step-1-fork-the-repository)
- [Repository Structure](#repository-structure)
- [Deploying Traefik](#deploying-traefik)
  - [Add Helm Repository & Install Traefik](#add-helm-repository--install-traefik)
  - [Configure Traefik](#configure-traefik)
  - [Deploy Traefik](#deploy-traefik)
  - [Deploy Traefik Ingress](#deploy-traefik-ingress)
- [Deploying Cert-Manager](#deploying-cert-manager)
  - [Add Helm Repository & Install Cert-Manager](#add-helm-repository--install-cert-manager)
  - [Configure Cert-Manager](#configure-cert-manager)
  - [Deploy Cert-Manager](#deploy-cert-manager)
  - [Obtain Cloudflare API Token](#obtain-cloudflare-api-token)
  - [Update Cluster Issuer and Issuer Secret](#update-cluster-issuer-and-issuer-secret)
  - [Deploy Cluster Issuer and Issuer Secret](#deploy-cluster-issuer-and-issuer-secret)
- [Deploying Longhorn](#deploying-longhorn)
  - [Preflight Checks](#preflight-checks)
  - [Install Dependencies](#install-dependencies)
  - [Deploy Longhorn](#deploy-longhorn)
- [Deploying CloudNative PostgreSQL](#deploying-cloudnative-postgresql)
  - [Add Helm Repository & Install CloudNative PostgreSQL](#add-helm-repository--install-cloudnative-postgresql)
- [Deploying LLDAP](#deploying-lldap)
  - [Create Namespace and Configure Secrets](#create-namespace-and-configure-secrets)
  - [Apply LLDAP Configuration](#apply-lldap-configuration)
- [Deploying Gitea](#deploying-gitea)
  - [Configure Gitea Secrets](#configure-gitea-secrets)
  - [Deploy Gitea](#deploy-gitea)
  - [Configure LLDAP Integration](#configure-lldap-integration)
  - [Push Repository to Gitea](#push-repository-to-gitea)
- [Deploying ArgoCD](#deploying-argocd)
  - [Configure LLDAP Integration](#configure-lldap-integration-argocd)
  - [Add Helm Repository & Install ArgoCD](#add-helm-repository--install-argocd)
  - [Configure ArgoCD](#configure-argocd)
  - [Install ArgoCD](#install-argocd)
  - [Deploy Argocd Ingress](#deploy-argocd-ingress)
  - [Retrieve Initial Password](#retrieve-initial-password)
  - [Access ArgoCD GUI](#access-argocd-gui)
- [Next Steps](#next-steps)

## Prerequisites

Before proceeding, ensure you have the following installed and configured:

- **Git**: To clone and manage repositories.
- **Kubernetes Cluster**: A working Kubernetes cluster.
- **kubectl**: To interact with your Kubernetes cluster.
- **Helm**: To manage Kubernetes applications.

## Fork the Repository

To begin, fork the repository to your own GitHub account.

1. Navigate to the repository: [dj346/homelab](https://github.com/dj346/homelab)
2. Click on the **Fork** button in the top-right corner.
3. Clone your forked repository to your local machine:

   ```sh
   git clone https://github.com/YOUR_GITHUB_USERNAME/homelab.git
   cd homelab
   ```

## Repository Structure

The repository is structured as follows:

```
kubernetes/
├── argocd/
│   └── prod-d1/
│       ├── app/
│       │   └── app.yaml
│       ├── certificate.yaml
│       ├── ingressroute.yaml
│       └── values.yaml
├── certmanager/
│   └── prod-d1/
│       ├── app/
│       │   └── app.yaml
│       ├── clusterissuer.yaml
│       ├── issuer-secret.yaml
│       └── values.yaml
├── gitea/
│   └── prod-d1/
│       ├── app/
│       │   └── app.yaml
│       ├── ingress.yaml
│       └── values.yaml
├── traefik/
│   └── prod-d1/
│       ├── app/
│       │   └── app.yaml
│       ├── dashboard-ingress.yaml
│       └── values.yaml
├── longhorn/
│   └── prod-d1/
│       ├── app/
│       │   └── app.yaml
│       ├── ingress.yaml
│       ├── values.yaml
│       └── storageclass.yaml
└── cnpg/
    └── prod-d1/
        ├── app/
        │   └── app.yaml
        └── values.yaml
```

Each directory corresponds to a Kubernetes application that will be deployed using ArgoCD. The `prod-d1` environment contains necessary manifests for deployment.

---

## Deploying Traefik

### Add Helm Repository & Install Traefik
```sh
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

### Configure Traefik
Navigate to the traefik [`values.yaml`](https://github.com/USERNAME/homelab/blob/main/kubernetes/traefik/prod-d1/values.yaml) and update `domain.com` to your domain:

### Deploy Traefik
```sh
helm install traefik traefik/traefik -f values.yaml --create-namespace --namespace traefik
```

Find the assigned IP:
```sh
kubectl get services -n traefik
```
Update your DNS to point `*.kube-prod-d1.domain.com` to the Traefik instance.

### Deploy Traefik Ingress
Navigate to the traefik [`dashboard-ingress.yaml`](https://github.com/USERNAME/homelab/blob/main/kubernetes/traefik/prod-d1/dashboard-ingress.yaml) and update `domain.com` to your domain:

```sh
kubectl apply -f dashboard-ingress.yaml
```

Verify at `https://traefik-dashboard.kube-prod-d1.domain.com/`.

---

## Deploying Cert-Manager

### Add Helm Repository & Install Cert-Manager
```sh
helm repo add jetstack https://charts.jetstack.io --force-update
```

### Configure Cert-Manager
Navigate to the certmanager [`values.yaml`](https://github.com/USERNAME/homelab/blob/main/kubernetes/certmanager/prod-d1/values.yaml) and update `domain.com` to your domain.

### Deploy Cert-Manager
```sh
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.16.3 -f values.yaml
```

### Obtain Cloudflare API Token
1. Navigate to the [Cloudflare API Tokens page](https://dash.cloudflare.com/profile/api-tokens).
2. Click **Create Token**.
3. Select **Edit zone DNS** (Use template).
4. Set the zones to **all zones** or specify a particular zone.
5. Click **Create Token** and save it for the next step.

### Update Cluster Issuer and Issuer Secret

Update `clusterissuer.yaml` and `issuer-secret.yaml` with your details, then apply them:
```sh
kubectl apply -f issuer-secret.yaml
kubectl apply -f clusterissuer.yaml
```

---

## Deploying Longhorn

For official Longhorn documentation, visit [Longhorn Installation Guide](https://longhorn.io/docs/1.8.1/deploy/install/).

### Preflight Checks

On your workstation, download the Longhorn CLI:
```sh
curl -sSfL -o longhornctl https://github.com/longhorn/cli/releases/download/v1.8.1/longhornctl-linux-amd64
chmod +x longhornctl
```

Ensure `KUBECONFIG` is set:
```sh
export KUBECONFIG=.kube/config
```
If not set, you may receive an error.

Run the Longhorn preflight check:
```sh
./longhornctl check preflight
```

### Install Dependencies

In my own setup, longhorn had me downloading these services (SSH in and run this on each node in your cluster):
```sh
sudo apt install -y open-iscsi nfs-common cryptsetup
sudo systemctl start iscsid
sudo systemctl enable iscsid
sudo modprobe dm_crypt
```

On your workstation, ensure CoreDNS is scaled properly:
```sh
kubectl scale deployment coredns --replicas=2 -n kube-system
```

### Deploy Longhorn

Navigate to `homelab/kubernetes/longhorn` and run:
```sh
helm repo add longhorn https://charts.longhorn.io/
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.8.1 -f values.yaml
kubectl apply -f ingress.yaml
kubectl apply -f storageclass.yaml
```

---

## Deploying CloudNative PostgreSQL

### Add Helm Repository & Install CloudNative PostgreSQL

```sh
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace --version 0.23.0
```

---

## Deploying LLDAP

### Create Namespace and Configure Secrets

Create the `lldap` namespace:
```sh
kubectl create namespace lldap
```

Update the following files with your credentials:
- `lldap-credentials-secret.yaml`
- `pgdb-connection-secret.yaml`
- `pgdb-service-user-secret.yaml`

Apply the secrets:
```sh
kubectl apply -f lldap-credentials-secret.yaml
kubectl apply -f pgdb-connection-secret.yaml
kubectl apply -f pgdb-service-user-secret.yaml
```

### Apply LLDAP Configuration

Deploy the required resources:
```sh
kubectl apply -f pgdb-cluster.yaml
kubectl apply -f certificate.yaml
kubectl apply -f dashboard-ingress.yaml
kubectl apply -f deployment.yaml
kubectl apply -f ingress-route.yaml
kubectl apply -f service.yaml
```

---

## Deploying Gitea

### Configure Gitea Secrets

Edit and deploy the following secret files with your credentials:
```sh
kubectl apply -f gitea-bind-user-secret.yaml
kubectl apply -f pgdb-service-user-secret.yaml
```

### Deploy Gitea Ingress

Deploy the ingress configuration:
```sh
kubectl apply -f ingress.yaml
kubectl apply -f giteadb-cluster.yaml
```

### Deploy Gitea

Add the Gitea Helm repository:
```sh
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update
```

Install Gitea:
```sh
helm install gitea gitea-charts/gitea --create-namespace --namespace gitea --version 10.6.0 -f values.yaml
```

### Configure LLDAP Integration

1. Log in to the LLDAP dashboard.
2. Create a new account called `gitea-service`.
3. Assign the role `lldap_strict_readonly` to `gitea-service`.
4. Create two new groups: `gitea-users` and `gitea-admins`.
5. Create your primary user (e.g., `dj346`).
6. Assign your primary user to the `gitea-admins` group.

### Push Repository to Gitea

Log in to Gitea and create a new repository named `homelab`.

On your local machine, navigate to your `homelab` repository and run:
```sh
cd homelab

git remote add origin https://gitea.kube-prod-d1.mclacken.net/dj346/homelab.git
git push -u origin main
```

---

## Deploying ArgoCD

### Configure LLDAP Integration

1. Update `ldap-bind-user-secret.yaml` with your credentials and apply it.
```sh
kubectl create namespace argocd
kubectl apply -f ldap-bind-user-secret.yaml
```
2. Create an LLDAP service account named `argocd-service`.
3. Assign the role `lldap_strict_readonly` to `argocd-service`.
4. Create two new groups: `argocd-admins` and `argocd-users`.
5. Assign your primary user (e.g., `dj346`) to the `argocd-admins` group.

### Add Helm Repository & Install ArgoCD
```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Install ArgoCD
```sh
helm install argocd argo-cd/argo-cd --create-namespace --namespace argocd -f values.yaml
```
> **Note:** This might take a second or two.

### Deploy Argocd Ingress
Deploy the config with:
```sh
kubectl apply -f ingressroute.yaml
```

### Retrieve Initial Password
```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Access ArgoCD GUI
Login at `https://argocd.kube-prod-d1.domain.com` with username `admin` and the retrieved password. Change the password immediately.

To enhance security, delete the initial admin secret **after** changing the password:
```sh
kubectl delete secret argocd-initial-admin-secret -n argocd
```
