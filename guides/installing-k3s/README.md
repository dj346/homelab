# Setting Up a k3s Cluster on Proxmox

This guide documents the process of setting up a k3s cluster using Proxmox-based virtual machines (VMs). The setup includes detailed configuration steps for VMs, securing the operating system, and initializing the cluster.

---

## Table of Contents

1. [VM Configuration](#vm-configuration)
   - [VM Specifications](#vm-specifications)
   - [Initial Setup](#initial-setup)
2. [Securing the Operating System](#securing-the-operating-system)
   - [SSH Configuration](#ssh-configuration)
   - [Restricting `su`](#restricting-su)
3. [Static IP Configuration](#static-ip-configuration)
4. [Cluster Setup](#cluster-setup)
   - [Installing kubectl](#installing-kubectl)
   - [Installing k3sup](#installing-k3sup)
   - [Installing k3s](#installing-k3s)
   - [Configuring kube-vip](#configuring-kube-vip)
   - [Adding Worker Nodes](#adding-worker-nodes)
   - [Clean up config](#clean-up-config)
   - [Install the kube-vip Cloud Provider](#install-the-kube-vip-cloud-provider)
5. [Afterwards](#afterwards)
   - [Create a backup](#create-a-backup)

---

## VM Configuration

### VM Specifications

**Proxmox VMs Created:**
- **ksrv-prod-d1** (ID: 111)
- **ksrv-prod-d2** (ID: 112)
- **ksrv-prod-d3** (ID: 113)

**Machine Roles:**
- Two VMs on a strong machine (IDs 111 and 112) serve as the master and primary worker nodes.
- One VM on a weaker machine (ID 113) serves as an additional worker node.

> **Naming Convention:** ksrv-prod-dX stands for “kube server - production - region D”, where X is the node identifier.


**Specifications for Each VM:**

| VM ID  | CPU Cores | Memory  | Disk      | MTU  | Notes                 |
|--------|-----------|---------|-----------|------|-----------------------|
| 111    | 4         | 20 GB   | 100 GB    | 9000 | Master Node           |
| 112    | 4         | 20 GB   | 100 GB    | 9000 | Worker Node           |
| 113    | 2         | 5.5 GB    | 100 GB    | 1500 | Weaker Worker Node    |

> **Note:** The memory allocation for `ksrv-prod-d1` and `ksrv-prod-d2` is subject to adjustment as needed.

**Proxmox Configuration:**
- OS: Debian 12
- Enabled QEMU agent.
- CPU type set to `host`.
- Disk type: SCSI on local storage (not NAS).
- MTU: Configured for 9000 on fiber-connected devices; 1500 for non-fiber.

### Initial Setup

1. Install Debian without LVM and in a headless configuration.
2. Login as root and install the following packages:
   ```bash
   apt install sudo curl jq -y
   sudo adduser {USER} sudo

   sudo apt update && sudo apt upgrade -y

   sudo reboot
   ```

---

## Securing the Operating System

### SSH Configuration

1. Backup and secure the SSH moduli file:
   ```bash
   sudo cp --archive /etc/ssh/moduli /etc/ssh/moduli-COPY-$(date +"%Y%m%d%H%M%S")
   sudo awk '$5 >= 3071' /etc/ssh/moduli | sudo tee /etc/ssh/moduli.tmp
   sudo mv /etc/ssh/moduli.tmp /etc/ssh/moduli
   ```

### Restricting `su`

1. Create a group for `su` access:
   ```bash
   sudo groupadd suusers
   ```

2. Add users to the group:
   ```bash
   sudo usermod -a -G suusers $USER
   ```

3. Restrict `su` to the group:
   ```bash
   sudo dpkg-statoverride --update --add root suusers 4750 /bin/su
   ```

---

## Static IP Configuration

Edit the network interface file to assign static IPs:
```bash
sudo vim /etc/network/interfaces
```
Example configuration:
```plaintext
iface ens18 inet static
    address 10.15.21.11/24
    network 10.15.21.0
    broadcast 10.15.21.255
    gateway 10.15.21.28
    dns-nameservers 10.15.21.1
```
Restart now:
```bash
sudo reboot
```
Add DNS entries for the VMs in your DNS server:
```plaintext
10.15.21.10 kube-prod-d1.local.DOMAIN
10.15.21.11 ksrv-prod-d1.local.DOMAIN
10.15.21.12 ksrv-prod-d2.local.DOMAIN
10.15.21.13 ksrv-prod-d3.local.DOMAIN
```
>**Note:** 10.15.21.10 is the future address for our loadbalancer. 

Now that we have static ips we can generate and distribute the SSH keys from our main device:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "your_email@example.com"
   ssh-copy-id -i ~/.ssh/id_rsa.pub {USER}@ksrv-prod-d1.local.DOMAIN
   ssh-copy-id -i ~/.ssh/id_rsa.pub {USER}@ksrv-prod-d2.local.DOMAIN
   ssh-copy-id -i ~/.ssh/id_rsa.pub {USER}@ksrv-prod-d3.local.DOMAIN
   ```

---

## Cluster Setup

### Installing kubectl
On your main computer, install `kubectl`:
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -m 755 kubectl /usr/local/bin/
```

### Installing k3sup

On your main computer, install `k3sup`:
```bash
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/
```

### Installing k3s

> **Note:** Somewhat helpful [guide](https://youtu.be/2cbniIZUpXM?si=kRNTAjhnqQ7rBreM&t=1244) in installing k3s.

1. Disable the sudo password temporarily on the master node:
   ```bash
   echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
   sudo -v
   ```

2. Make sure the directory exists where the config will be saved (on your main computer):
   ```bash
   mkdir -p $HOME/.kube/
   ```

3. Install k3s on the master node (run this on your main computer not the master node):
   ```bash
   k3sup install \
       --ip 10.15.21.11 \
       --tls-san 10.15.21.10 \
       --tls-san kube-prod-d1.local.{DOMAIN} \
       --cluster \
       --k3s-channel latest \
       --k3s-extra-args "--disable servicelb --disable traefik" \
       --local-path $HOME/.kube/config \
       --user {USER} 
   ```
   > **Note:** Make sure to replace {USER} with your username, and {DOMAIN} with your domain

### Configuring kube-vip

Follow the official guide: [Kube-Vip Documentation](https://kube-vip.io/docs/usage/k3s/).

1. Go to the master node and create required directories and files:
   ```bash
   su
   mkdir -p /var/lib/rancher/k3s/server/manifests/
   curl https://kube-vip.io/manifests/rbac.yaml > /var/lib/rancher/k3s/server/manifests/kube-vip-rbac.yaml
   ```

2. Set environment variables:
   ```bash
   export VIP=10.15.21.10
   export INTERFACE=ens18
   KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")
   alias kube-vip="ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION; ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip"
   ```
   > **Note:** Make sure to replace VIP and INTERFACE if your values are different, VIP should be the ip you want your loadbalancer to be on (different from all the node ips)

3. Generate app manifest:
   ```bash
   kube-vip manifest daemonset \
       --interface $INTERFACE \
       --address $VIP \
       --inCluster \
       --taint \
       --controlplane \
       --services \
       --arp \
       --leaderElection
   ```
4. Copy the yaml output from the above command and save it in and apply.
   ```bash
   sudo vim /var/lib/rancher/k3s/server/manifests/kube-vip-manifest.yaml
   sudo kubectl apply -f /var/lib/rancher/k3s/server/manifests/kube-vip-manifest.yaml
   ```

5. Verify the setup:
   ```bash
   sudo k3s kubectl get daemonsets --all-namespaces
   ```

### Adding Worker Nodes

1. Disable the sudo password temporarily on each worker node:
   ```bash
   echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
   sudo -v
   ```
   > **Note:** Make sure to replace {USER} with your username

2. Add the worker nodes (I made my second node a master node with the ```--server``` flag because I want two master nodes and 1 worker node in my configuration, if you want two worker nodes remove the above flag):
   ```bash
   k3sup join \
       --ip 10.15.21.12 \
       --server-ip 10.15.21.11 \
       --k3s-channel latest \
       --server \
       --user {USER}

   k3sup join \
       --ip 10.15.21.13 \
       --server-ip 10.15.21.11 \
       --k3s-channel latest \
       --user {USER}
   ```
   > **Note:** Make sure to replace {USER} with your username

3. Re-enable the sudo password on all nodes:
   ```bash
   sudo sed -i '/$USER ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers
   ```
   > **Note:** Make sure to replace {USER} with your username

4. Confirm everything was sucessful
   ```bash
   kubectl get node -o wide
   ```

### Clean up config


1. If everything was successful you should be able to edit your k3s config on your main machine:
   ```bash
   vim $HOME/.kube/config
   ```

2. Id recommend changing the config from:
   ```yaml
   apiVersion: v1
   clusters:
   - cluster:
      certificate-authority-data: {CERTIFICATE-AUTHORITY-DATA}
      server: https://10.15.21.11:6443
   name: default
   contexts:
   - context:
      cluster: default
      user: default
   name: default
   current-context: default
   kind: Config
   preferences: {}
   users:
   - name: default
   user:
      client-certificate-data: {CLIENT-CERTIFICATE-DATA}
      client-key-data: {CLIENT-KEY-DATA}
      ```
   To:
   ```yaml
   apiVersion: v1
   clusters:
   - cluster:
      certificate-authority-data: {CERTIFICATE-AUTHORITY-DATA}
      server: https://kube-prod-d1.local.{DOMAIN}:6443
   name: kube-prod-d1
   contexts:
   - context:
      cluster: kube-prod-d1
      user: kube-prod-d1-admin
   name: kube-prod-d1
   current-context: kube-prod-d1
   kind: Config
   preferences: {}
   users:
   - name: kube-prod-d1-admin
   user:
      client-certificate-data: {CLIENT-CERTIFICATE-DATA}
      client-key-data: {CLIENT-KEY-DATA}
      ```

### Install the kube-vip Cloud Provider

1. Reference: [guide](https://kube-vip.io/docs/usage/cloud-provider/):

2. Install the kube-vip Cloud Provider
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
   ```
3. Create a global CIDR or IP Range
   ```bash
   kubectl create configmap -n kube-system kubevip --from-literal range-global=192.168.1.220-192.168.1.230
   ```
   OR
   ```bash
   kubectl create configmap -n kube-system kubevip --from-literal cidr-global=192.168.0.220/29
   ```

---

## Afterwards

### Create a backup

1. Now that youve setup your kubernetes cluster, id highly recommend building a backup of your cluster in proxmox so that in the event you wipe everything away youll have something to fall on.  

2. Done.