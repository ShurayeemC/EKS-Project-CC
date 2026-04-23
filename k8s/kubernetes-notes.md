# Kubernetes Manifests — End to End Revision Notes
## EKS Project Interview Prep

---

## Table of Contents

1. [The Full Picture](#the-full-picture--how-everything-connects)
2. [Deployment (deployment.yaml)](#deployment-deploymentyaml)
3. [Service (svc.yaml)](#service-svcyaml)
4. [Ingress (ingress.yaml)](#ingress-ingressyaml)
5. [Middleware (middleware.yaml)](#middleware-middlewareyaml)
6. [ClusterIssuer (clusterissuer.yaml)](#clusterissuer-clusterissueryaml)
7. [PodDisruptionBudget (pdb.yaml)](#poddisruptionbudget-pdbyaml)
8. [HorizontalPodAutoscaler (hpa.yaml)](#horizontalpodautoscaler-hpayaml)
9. [NetworkPolicy (networkpolicy.yaml)](#networkpolicy-networkpolicyyaml)
10. [Key Interview Concepts](#key-concepts-to-know-for-the-interview)

---

## The Full Picture — How Everything Connects

When a user visits https://sc-k8sapp.com this is what happens:

```
User types sc-k8sapp.com
    ↓
Cloudflare DNS resolves to AWS NLB (created by Traefik)
    ↓
NLB forwards to Traefik pod
    ↓
Traefik checks Ingress rules — finds sc-k8sapp.com matches
    ↓
Traefik checks Middleware — rate limit OK? → continue
    ↓
Traefik forwards to Service (app2048service) on port 80
    ↓
Service load balances across healthy pods on port 3000
    ↓
Pod serves the 2048 app
```

TLS is handled transparently — CertManager issued the certificate, it's stored as a Kubernetes Secret, Traefik presents it to the user's browser.

---

# Kubernetes Manifest Files Breakdown

## Deployment (`deployment.yaml`)

The Deployment is the core resource. It manages your application pods and ensures the desired state is always maintained.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eks-deployment
  namespace: app
  labels:
    app: 2048-app
    environment: production
    team: platform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: 2048-app
  template:
    metadata:
      labels:
        app: 2048-app
        environment: production
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: 2048-app
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: 2048-app
        image: 321431649440.dkr.ecr.eu-west-2.amazonaws.com/sc-eks-ecr:<SHA>
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
```

### What each section does

**`apiVersion: apps/v1`** — tells Kubernetes which API group to use. Deployments live in the `apps` group. The version is pinned to `v1` which is stable — features graduate from alpha → beta → stable.

**`kind: Deployment`** — the resource type. A Deployment manages a ReplicaSet which manages Pods. You never touch the ReplicaSet or Pods directly — you tell the Deployment what you want and it handles everything below.

The hierarchy is:
```
Deployment → manages → ReplicaSet → manages → Pods
```

**`namespace: app`** — every app gets its own namespace in production. The `default` namespace is bad practice because:
- No isolation between teams or services
- Can't apply network policies per service
- Can't set resource quotas per team
- No RBAC per service

**`labels`** — key-value tags on the resource. Three purposes:
- `app: 2048-app` — used by the selector to find pods
- `environment: production` — filtering and cost allocation
- `team: platform` — ownership, so at 3am when something breaks someone knows who to call

**`replicas: 2`** — how many identical pods to run. If a pod dies, the Deployment controller immediately creates a replacement. This is self-healing.

**`selector.matchLabels`** — how the Deployment finds which pods it owns. Must match the labels in the pod template. This is the link between the Deployment and its pods.

**`template`** — the blueprint for every pod. The Deployment stamps out pods using this blueprint. Every pod created will look exactly like this template.

---

### Topology Spread Constraints

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: 2048-app
```

This ensures pods are spread across AWS Availability Zones. Without this Kubernetes might put all pods on nodes in eu-west-2a. If that AZ goes down your entire app goes down even though you have replicas.

**`topologyKey: topology.kubernetes.io/zone`** — AWS automatically labels every node with its AZ. Kubernetes reads this label to know which AZ each node is in.

**`maxSkew: 1`** — maximum allowed difference in pod count between zones. With 2 pods across 2 zones you get 1 per zone — perfect balance. `maxSkew: 1` allows a difference of 1 which is the minimum possible for an odd number of pods.

**`whenUnsatisfiable: DoNotSchedule`** — if the scheduler can't place the pod without violating the spread, it leaves it Pending rather than breaking the constraint. Better to wait than to concentrate pods in one zone.

Result with 2 pods:
```
eu-west-2a: 1 pod (ip-10-0-3-169)
eu-west-2b: 1 pod (ip-10-0-4-169)
```

If eu-west-2a goes down — eu-west-2b still has a pod serving traffic.

---

### Pod Security Context (pod level)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
```

Applies to ALL containers in the pod.

**`runAsNonRoot: true`** — Kubernetes rejects the pod if the container tries to run as root (user ID 0). This is enforced at the platform level before the container even starts.

Why it matters: if someone exploits a vulnerability in your app and breaks out of the container, they'd have root on the underlying node. User 1000 is a non-privileged user — the blast radius of a container escape is massively reduced.

**`runAsUser: 1000`** — explicitly sets the UID. Root is 0. User 1000 is a standard non-privileged user.

**`fsGroup: 2000`** — any volumes mounted to this pod will be owned by group 2000. Important for shared storage.

---

### Resources

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

Two distinct concepts — requests and limits are NOT the same thing.

**Requests** — the minimum guaranteed resources. The Kubernetes scheduler uses this to decide which node to place the pod on. If a node doesn't have 64Mi free memory available, the pod won't be scheduled there.

**Limits** — the hard ceiling. If the pod tries to use more than 128Mi of memory it gets OOMKilled (Out Of Memory Killed) and restarted automatically. CPU limits throttle the process rather than killing it.

`100m` CPU = 100 millicores = 0.1 of a vCPU. 1000m = 1 full vCPU.

Without resource limits: one misbehaving pod can consume all node resources and starve every other pod on that node — taking down unrelated services.

---

### Liveness Probe

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3
```

Answers: **"Is this pod alive?"**

Kubernetes hits `http://pod-ip:3000/` every 10 seconds. If it gets 3 consecutive failures — it kills the pod and creates a new one. Self-healing.

`initialDelaySeconds: 10` — waits before the first check. Without this the probe fires immediately and could kill the pod before the app has started.

`failureThreshold: 3` — 3 consecutive failures before action. Prevents flapping — a single slow response doesn't kill the pod.

---

### Readiness Probe

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

Answers: **"Is this pod ready to receive traffic?"**

If this fails, Kubernetes removes the pod from the Service's load balancer. Traffic stops going to it — but the pod is NOT restarted. It just stops receiving traffic until it recovers.

**The critical difference:**
- Liveness failure → pod is restarted
- Readiness failure → pod removed from load balancer, not restarted

A pod can be alive but not ready — for example during startup, or when temporarily overloaded. Readiness prevents traffic going to a pod that can't handle it, without killing it unnecessarily.

---

### Container Security Context (container level)

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  capabilities:
    drop:
    - ALL
```

More granular than pod-level — applies only to this specific container.

**`allowPrivilegeEscalation: false`** — prevents any process inside the container gaining more privileges than it started with. Stops `sudo`, `setuid` binaries, or kernel exploits that try to escalate to root.

**`readOnlyRootFilesystem: false`** — in fully hardened production this would be `true`, preventing writes to the container filesystem. We set `false` because Python's HTTP server needs to write temp files.

**`capabilities: drop: ALL`** — the most impactful security hardening. Linux capabilities are fine-grained permissions:
- `NET_ADMIN` — configure network interfaces
- `SYS_ADMIN` — perform system administration tasks
- `CHOWN` — change file ownership
- `SYS_PTRACE` — trace other processes

By dropping ALL of them the container has the absolute minimum privileges. Even if someone exploits the app, they can't use any kernel capabilities.

---

## Service (`svc.yaml`)

### Overview
The Service provides a stable internal endpoint to reach your pods.

### YAML Configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app2048service
  namespace: app
  labels:
    app: 2048-app
    environment: production
    team: platform
spec:
  selector:
    app: 2048-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
```

### Why Services exist

Pods are ephemeral — they get created and destroyed constantly. Every time a pod restarts it gets a new IP address. If Traefik tried to talk directly to pod IPs, it would break every time a pod restarted.

The Service has a stable IP address (ClusterIP) that never changes. Traefik talks to the Service IP, and the Service forwards to whatever pods are currently healthy.

**`selector: app: 2048-app`** — the Service finds pods using this label. Any pod in the `app` namespace with `app: 2048-app` label gets traffic from this Service. When new pods are created by the Deployment they automatically start receiving traffic.

**`port: 80`** — the port the Service listens on internally within the cluster.

**`targetPort: 3000`** — the port the container is actually running on. The Service translates port 80 → 3000. This is why Traefik sends to port 80 but the app listens on 3000.

**Type: ClusterIP (default)** — this Service is only accessible inside the cluster. It has no external IP. External traffic enters through Traefik, not through the Service directly.

The Service also load balances — if you have 3 pods, the Service round-robins requests across all 3 automatically.

---

## Ingress (`ingress.yaml`)

### Overview
The Ingress defines the routing rules for external traffic. Traefik reads this and knows how to route requests.

### YAML Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app2048-ingress
  namespace: app
  labels:
    app: 2048-app
    environment: production
    team: platform
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.middlewares: traefik-redirect-to-https@kubernetescrd,app-ratelimit@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - sc-k8sapp.com
    secretName: app2048-tls
  rules:
  - host: sc-k8sapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2048service
            port:
              number: 80
```

### Annotations

Annotations are metadata that tools read to configure their behaviour. Unlike labels which Kubernetes uses internally, annotations are for external tools.

**`cert-manager.io/cluster-issuer: letsencrypt-production`** — tells CertManager "when this Ingress is created, automatically request a TLS certificate from the `letsencrypt-production` ClusterIssuer." CertManager does the ACME challenge, gets the cert, stores it as a Secret, and attaches it to this Ingress.

**`traefik.ingress.kubernetes.io/router.entrypoints: websecure`** — tells Traefik to only accept HTTPS traffic on this route. `websecure` is Traefik's name for port 443.

**`traefik.ingress.kubernetes.io/router.middlewares`** — chains middleware. Two middlewares are applied in order:
1. `traefik-redirect-to-https` — any HTTP request gets 301 redirected to HTTPS
2. `app-ratelimit` — rate limiting applied after the redirect

### TLS block

```yaml
tls:
- hosts:
  - sc-k8sapp.com
  secretName: app2048-tls
```

Tells Traefik to serve TLS for `sc-k8sapp.com` using the certificate stored in the Secret `app2048-tls`. CertManager creates this Secret automatically when it gets the certificate from Let's Encrypt.

### Rules

```yaml
rules:
- host: sc-k8sapp.com
  http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: app2048service
          port:
            number: 80
```

When Traefik receives a request for `sc-k8sapp.com` with any path starting with `/` — forward it to the Service `app2048service` on port 80.

`pathType: Prefix` means `/`, `/about`, `/api/anything` all match. For exact matching you'd use `pathType: Exact`.

In a microservices setup you'd have multiple rules:
```
sc-k8sapp.com/api    → api-service:80
sc-k8sapp.com/auth   → auth-service:80
sc-k8sapp.com/       → frontend-service:80
```

---

## Middleware (`middleware.yaml`)

### Overview
The Middleware defines reusable request processing rules for Traefik.

### YAML Configuration

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: app-ratelimit
  namespace: app
  labels:
    app: 2048-app
    environment: production
    team: platform
spec:
  rateLimit:
    average: 100
    burst: 50
    period: 1s
```

### Why Rate Limiting

Without it anyone can send unlimited requests to your app — enabling DDoS attacks, brute force attacks, and resource exhaustion that affects all users.

**`average: 100`** — each client IP is allowed 100 requests per second sustained.

**`burst: 50`** — allows short spikes of 50 extra requests above the average before throttling. Prevents legitimate users being blocked for a momentary spike.

**`period: 1s`** — the time window for rate calculation.

If a client exceeds the limit Traefik returns `429 Too Many Requests` automatically. The request never reaches your pods.

**Separation of concerns:** The rules live in `middleware.yaml`. The Ingress just references it by name (`app-ratelimit@kubernetescrd`). This means you can reuse the same rate limit across multiple Ingress resources without duplicating the config.

---

## ClusterIssuer (`clusterissuer.yaml`)

### Overview
The ClusterIssuer tells CertManager how to get TLS certificates.

### YAML Configuration

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    email: shurayeem@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-production-key
    solvers:
    - http01:
        ingress:
          ingressClassName: traefik
```

### ClusterIssuer vs Issuer

An `Issuer` is namespace-scoped — it can only issue certificates for resources in the same namespace. A `ClusterIssuer` is cluster-wide — it can issue certificates for any namespace. We use ClusterIssuer so it works regardless of which namespace the Ingress is in.

**ACME protocol:**

ACME (Automatic Certificate Management Environment) is the protocol Let's Encrypt uses. CertManager implements it automatically.

**`server`** — the Let's Encrypt production API. There's also a staging server for testing that doesn't have rate limits but issues untrusted certificates.

**`privateKeySecretRef`** — CertManager stores your Let's Encrypt account private key in this Secret. Used to authenticate to Let's Encrypt for future renewals.

**HTTP01 solver:**

When Let's Encrypt needs to verify you own the domain, it uses an HTTP01 challenge:
1. Let's Encrypt tells CertManager to host a specific file at `http://sc-k8sapp.com/.well-known/acme-challenge/<token>`
2. CertManager creates a temporary Ingress rule via Traefik to serve that file
3. Let's Encrypt fetches the file — if it's there, domain ownership is proved
4. Certificate is issued
5. Temporary Ingress rule is removed
6. Certificate is stored as a Secret and attached to your Ingress

CertManager also handles automatic renewal — certificates are renewed 30 days before expiry, transparently, with no manual intervention.

---

## PodDisruptionBudget (`pdb.yaml`)

### Overview
The PDB protects your app during planned maintenance.

### YAML Configuration

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app2048-pdb
  namespace: app
  labels:
    app: 2048-app
    environment: production
    team: platform
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: 2048-app
```

### Types of Disruptions

**Involuntary** — hardware failures, OOM kills. PDB does NOT protect against these.

**Voluntary** — node drains for maintenance, cluster upgrades, scaling down. PDB DOES protect against these.

**`minAvailable: 2`** — Kubernetes must always keep at least 2 pods running during voluntary disruptions.

Without a PDB: a node drain could evict all pods simultaneously → complete downtime.

With this PDB: if Kubernetes needs to drain a node it:
1. Checks — are 2 pods still running? Yes → evict one pod
2. Waits for replacement to start
3. Checks — are 2 pods still running? Yes → evict next pod
4. Never drops below 2 running pods

**`ALLOWED DISRUPTIONS: 1`** in the output means with 2 pods running and minAvailable of 2 — only 1 pod can be disrupted at a time.

---

## HorizontalPodAutoscaler (`hpa.yaml`)

### Overview
The HPA automatically scales pod count based on CPU usage.

### YAML Configuration

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app2048-hpa
  namespace: app
  labels:
    app: 2048-app
    environment: production
    team: platform
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: eks-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Configuration Details

**`scaleTargetRef`** — which resource to scale. Points at your Deployment by name.

**`minReplicas: 2`** — never scale below 2 pods even at zero load. Maintains high availability.

**`maxReplicas: 10`** — maximum pods under heavy load. Prevents unbounded scaling that could exhaust node capacity.

**`averageUtilization: 70`** — when the average CPU across all pods exceeds 70%, the HPA adds more pods. When CPU drops back down, it removes pods down to the minimum.

**HPA takes ownership of replica count** — once HPA is attached, the `replicas` field in the Deployment is ignored. HPA manages the count dynamically.

**Requires metrics server** — HPA needs the Kubernetes metrics server to collect CPU data from pods. We installed this separately:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## NetworkPolicy (`networkpolicy.yaml`)

### Overview
The NetworkPolicy implements zero-trust networking — by default deny everything, then explicitly allow only what's needed.

### YAML Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app2048-network-policy
  namespace: app
  labels:
    app: 2048-app
    environment: production
    team: platform
spec:
  podSelector:
    matchLabels:
      app: 2048-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: traefik
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

### Policy Configuration

**`podSelector`** — which pods this policy applies to. Only pods with `app: 2048-app` label are affected.

**`policyTypes: Ingress + Egress`** — we're controlling both directions. By specifying both, all unlisted traffic is denied by default.

**Ingress rule — who can send traffic IN:**

Only pods in the `traefik` namespace can reach your app pods on port 3000. Nothing else in the cluster can reach them directly — not other pods, not other namespaces.

```
Traefik (allowed) → port 3000 → App pods
Everything else   → BLOCKED
```

**Egress rule — what can your pods send OUT:**

Your app pods can only make DNS lookups (port 53) to kube-system where CoreDNS lives. DNS is needed for any hostname resolution. Everything else your pods try to send out is blocked — they can't call external APIs, can't talk to other pods in other namespaces, can't reach the internet.

**Why this matters:**

Without network policy — if any pod gets compromised an attacker can talk freely to any other pod in the cluster (lateral movement).

With network policy — even if a pod is compromised, the attacker can only make DNS lookups. They're stuck.

This is called **defence in depth** — multiple layers of security so a single failure doesn't compromise everything.

---

## Key Concepts to Know for the Interview

**Deployment vs Pod:**
Never run bare pods in production. A bare pod that crashes is gone forever — nothing restarts it. A Deployment's ReplicaSet immediately replaces crashed pods.

**Liveness vs Readiness:**
- Liveness = "is it alive?" → fail → restart
- Readiness = "is it ready?" → fail → remove from load balancer, don't restart

**Requests vs Limits:**
- Requests = scheduling guarantee (minimum)
- Limits = hard ceiling (maximum)

**Service types:**
- ClusterIP — internal only (what we use)
- NodePort — exposes on each node's IP
- LoadBalancer — creates a cloud load balancer (what Traefik uses)

**Namespace isolation:**
Each service gets its own namespace. RBAC, network policies, and resource quotas can all be applied per namespace. Traefik still routes to all namespaces.

**The GitOps flow:**
```
Push to GitHub → GitHub Actions builds image → Pushes to ECR → 
Updates deployment.yaml → ArgoCD detects change → Deploys to cluster
```

**IRSA:**
IAM Roles for Service Accounts. Pods assume AWS IAM roles without static credentials. ExternalDNS uses IRSA to update Route 53 records automatically when Ingress resources are created.

**Zero trust networking:**
Default deny all traffic. Explicitly allow only what's needed. NetworkPolicy implements this at the pod level inside the cluster.