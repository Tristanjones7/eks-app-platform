# eks-app-platform

A production-style application platform on **Amazon EKS**, provisioned end-to-end with **Terraform**. A containerized FastAPI service is built, scanned, stored in ECR, and deployed to a hardened Kubernetes cluster with health probes, resource limits, secret management, load balancing, and full Prometheus/Grafana observability.

> Built as a hands-on demonstration of cloud infrastructure, container orchestration, and DevOps automation.

---

## Architecture

\`\`\`mermaid
flowchart TB
    User([Internet User]) -->|HTTP :80| ELB[AWS Load Balancer]

    subgraph VPC["VPC 10.0.0.0/16 — 3 Availability Zones"]
        subgraph Public["Public Subnets"]
            ELB
            NAT[NAT Gateway]
        end
        subgraph Private["Private Subnets"]
            subgraph EKS["EKS Cluster (managed node group)"]
                SVC[Service: eks-app] --> P1[Pod: eks-app]
                SVC --> P2[Pod: eks-app]
                P1 --> SEC[(Kubernetes Secret)]
                P2 --> SEC
            end
        end
    end

    ELB --> SVC
    P1 -.->|pull image| ECR[(Amazon ECR<br/>scan-on-push)]
    P2 -.->|pull image| ECR

    subgraph Monitoring["monitoring namespace"]
        PROM[Prometheus] --> GRAF[Grafana]
    end
    PROM -.->|scrape metrics| EKS
\`\`\`

---

## What this project demonstrates

- **Infrastructure as Code** — the entire AWS footprint (VPC, subnets, NAT, EKS control plane, managed node group, IAM, KMS, ECR) is defined in Terraform. No console clicking.
- **Container orchestration** — a real app running on Kubernetes with Deployments, Services, probes, resource limits, and self-healing.
- **Security hardening** — non-root containers, read-only root filesystem, dropped Linux capabilities, KMS-encrypted secrets, IMDSv2 enforced, image vulnerability scanning.
- **Observability** — Prometheus scraping cluster and pod metrics, visualized in Grafana dashboards.
- **Cost awareness** — single NAT gateway, small node group, and one-command teardown.

## Tech stack

| Layer | Tools |
|-------|-------|
| IaC | Terraform (terraform-aws-modules for VPC & EKS) |
| Cloud | AWS — EKS, EC2, VPC, ECR, IAM, KMS, ELB |
| Containers | Docker, Amazon ECR |
| Orchestration | Kubernetes (EKS), kubectl |
| App | Python, FastAPI, Uvicorn |
| Observability | Prometheus, Grafana (kube-prometheus-stack via Helm) |

## Repository structure

\`\`\`
eks-app-platform/
├── .devcontainer/        # Pinned toolchain (terraform, kubectl, helm, aws, docker)
├── terraform/            # VPC, EKS cluster, managed node group, ECR
├── app/                  # FastAPI service + Dockerfile
├── k8s/                  # Deployment, Service, Namespace, Secret example
└── README.md
\`\`\`

---

## How to deploy

**Prerequisites:** an AWS account with credentials configured, and the tools in .devcontainer (Terraform, kubectl, Helm, AWS CLI, Docker).

### 1. Provision the cluster and registry

\`\`\`bash
cd terraform
terraform init
terraform apply        # ~15 min for the EKS control plane
aws eks update-kubeconfig --region us-east-1 --name eks-app-platform
kubectl get nodes      # expect 2 Ready nodes
\`\`\`

### 2. Build and push the image

\`\`\`bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR="$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR

cd ../app
docker build -t eks-app-platform:1.0.0 .
docker tag eks-app-platform:1.0.0 $ECR/eks-app-platform:1.0.0
docker push $ECR/eks-app-platform:1.0.0
\`\`\`

### 3. Deploy to Kubernetes

\`\`\`bash
cd ../k8s
kubectl apply -f namespace.yaml
kubectl create secret generic eks-app-secret -n demo \
  --from-literal=greeting="Hello from eks-app-platform"
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

kubectl get svc -n demo     # copy the EXTERNAL-IP once provisioned
curl http://<EXTERNAL-IP>/  # returns greeting, version, and pod name
\`\`\`

### 4. Observability

\`\`\`bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring

# Grafana (user: admin)
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
\`\`\`

---

## Self-healing demo

Kubernetes continuously reconciles actual state toward desired state. Delete a pod and a replacement appears within seconds:

\`\`\`bash
kubectl delete pod -n demo <pod-name>
kubectl get pods -n demo -w     # replacement reaches Running with no intervention
\`\`\`

## Security notes

- Containers run as a **non-root** user (UID 1000) with a **read-only root filesystem** and **all Linux capabilities dropped**.
- Application config (GREETING) is injected from a **Kubernetes Secret**, never hardcoded or committed.
- EKS secrets are **encrypted at rest with a dedicated KMS key**.
- Worker nodes enforce **IMDSv2** (http_tokens = required).
- ECR performs **vulnerability scanning on every push**.
- Terraform **state and plan files are git-ignored** so no secrets reach the repository.

## Cost & teardown

This stack incurs cost while running (EKS control plane, EC2 nodes, NAT gateway, load balancer — roughly \$0.25/hr). Tear everything down with:

\`\`\`bash
kubectl delete -f k8s/ ; kubectl delete namespace monitoring

cd terraform
terraform destroy
\`\`\`
