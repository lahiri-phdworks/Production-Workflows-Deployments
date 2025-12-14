# Learning Helm, Kubernetes and GCP-TerraForm.

- [https://learn.kodekloud.com/user/dashboard](https://learn.kodekloud.com/user/dashboard)

## Commands.

Type `kubectl get nodes` in the terminal on the right and count the number of nodes that are listed.

```bash 
controlplane ~ ➜  kubectl get nodes
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   8m54s   v1.34.1+k3s1

controlplane ~ ➜  kubectl version 
Client Version: v1.34.1+k3s1
Kustomize Version: v5.7.1
Server Version: v1.34.1+k3s1

controlplane ~ ➜  kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/https:metrics-server:https/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## Creating and maintaining pods.

```bash
kubectl run nginx-pod --image=nginx
kubectl get pods
```

## Other variations

```bash 
kubectl get pods -o wide
```
