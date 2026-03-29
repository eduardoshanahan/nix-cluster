# Apache Spark on Kubernetes

This directory contains the complete Apache Spark deployment for the nix-cluster homelab environment.

## Overview

Apache Spark is deployed using the Spark Operator for Kubernetes, which manages SparkApplication workloads as native Kubernetes resources. The deployment includes:

- **Spark Operator**: Manages SparkApplication CRDs and orchestrates job lifecycle
- **Spark History Server**: Web UI for monitoring completed jobs
- **MinIO S3 Integration**: Event log storage for job history and data I/O
- **Prometheus Monitoring**: Metrics from operator and history server
- **Resource Quota**: 50% cluster capacity (20GB memory, 10 CPU)

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                        spark namespace                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐         ┌──────────────────────┐       │
│  │ Spark Operator  │────────▶│  SparkApplication    │       │
│  │  (Deployment)   │         │       (CRD)          │       │
│  └─────────────────┘         └──────────────────────┘       │
│         │                             │                      │
│         │ watches                     │ creates              │
│         │                             ▼                      │
│         │                    ┌─────────────────┐            │
│         │                    │  Driver Pod     │            │
│         │                    └─────────────────┘            │
│         │                             │                      │
│         │                             │ spawns               │
│         │                             ▼                      │
│         │                    ┌─────────────────┐            │
│         │                    │ Executor Pods   │            │
│         │                    └─────────────────┘            │
│         │                                                     │
│  ┌─────────────────────┐                                    │
│  │ History Server      │◀────── reads event logs ──────┐   │
│  │   (Deployment)      │                                 │   │
│  └─────────────────────┘                                 │   │
│         │                                                  │   │
│         │ exposed via                                     │   │
│         ▼                                                  │   │
│  ┌─────────────────────┐                                 │   │
│  │   Traefik Ingress   │                                 │   │
│  │ spark-history.      │                                 │   │
│  │  hhlab.home.arpa    │                                 │   │
│  └─────────────────────┘                                 │   │
│                                                            │   │
└────────────────────────────────────────────────────────────┼──┘
                                                              │
                    ┌─────────────────────────────────────────┘
                    │
                    ▼
          ┌──────────────────┐
          │  MinIO S3        │
          │  s3.hhlab.       │
          │  home.arpa       │
          │                  │
          │ spark-homelab/   │
          │  spark-events/   │
          └──────────────────┘
```

### Resource Allocation

The spark namespace has a ResourceQuota limiting usage to 50% of cluster capacity:

- **Memory**: 20GB request limit, 30GB hard limit
- **CPU**: 10 cores request limit, 15 cores hard limit
- **Pods**: 50 maximum
- **PVCs**: 10 maximum

This ensures Spark workloads don't starve other services on the cluster.

## Deployment

### Prerequisites

1. **MinIO S3 Bucket Setup**

   Before deploying, create the S3 bucket on your MinIO instance:

   ```bash
   # Access MinIO UI at s3.hhlab.home.arpa
   # Create bucket: spark-homelab
   # Generate access key for Spark
   ```

2. **Update nix-cluster-private**

   Add MinIO credentials to `nix-cluster-private/modules/shared.nix`:

   ```nix
   homelab.spark.minioEndpoint = "s3.hhlab.home.arpa";
   homelab.spark.minioBucket = "spark-homelab";
   homelab.spark.minioAccessKey = "<your-access-key>";
   homelab.spark.minioSecretKey = "<your-secret-key>";
   ```

### Render and Apply

From the nix-cluster repository root:

```bash
# Validate private config
nix run .#validate-private-config

# Render manifests with templated values
nix run .#render-spark > /tmp/spark-manifests.yaml

# Dry-run validation
kubectl apply --dry-run=client -f /tmp/spark-manifests.yaml

# Deploy to cluster
nix run .#render-spark | kubectl apply -f -
```

### Verify Deployment

```bash
# Check namespace and pods
kubectl get pods -n spark

# Should see:
# - spark-operator-<hash>           Running
# - spark-history-server-<hash>     Running

# Check CRDs
kubectl get crd | grep sparkoperator

# Should see:
# - sparkapplications.sparkoperator.k8s.io
# - scheduledsparkapplications.sparkoperator.k8s.io

# Check ingress
kubectl get ingress -n spark

# Check resource quota
kubectl describe resourcequota spark-quota -n spark
```

### Access History Server

Open browser to: https://spark-history.hhlab.home.arpa

You should see the Spark History Server UI (initially empty until jobs run).

## Usage

### Submitting Jobs

SparkApplications are submitted as Kubernetes resources:

```bash
# Submit example Pi calculation
kubectl apply -f kubernetes/apps/spark/examples/spark-pi.yaml

# Monitor job
kubectl get sparkapplications -n spark -w

# View driver logs
kubectl logs -n spark spark-pi-test-driver -f
```

### Job Monitoring

**CLI:**
```bash
# List all jobs
kubectl get sparkapplications -n spark

# Get job details
kubectl describe sparkapplication spark-pi-test -n spark

# Check executor pods
kubectl get pods -n spark | grep spark-pi-test

# Resource usage
kubectl top pods -n spark
```

**History Server UI:**
- Navigate to https://spark-history.hhlab.home.arpa
- View completed job details
- Inspect stages, tasks, and executor metrics

### Example Jobs

See `examples/README.md` for detailed documentation on:
- `spark-pi.yaml` - Classic Pi estimation (CPU test)
- `spark-s3-test.yaml` - S3 integration test (I/O test)

## Configuration

### Spark Operator

Configuration in `spark-operator/values.yaml`:

- **Resources**: 128Mi-256Mi memory, 100m-200m CPU
- **Metrics**: Exposed on port 10254
- **Webhook**: Enabled on port 9443
- **RBAC**: Full cluster permissions for SparkApplication management

### History Server

Configuration in `spark-history-server/deployment.yaml`:

- **S3 Event Logs**: `s3a://spark-homelab/spark-events/`
- **Retention**: 50 applications, 7 day log cleanup
- **Resources**: 512Mi-1Gi memory, 100m-500m CPU
- **UI Port**: 18080

### MinIO S3

Configuration in `minio-integration/secret.yaml`:

- **Endpoint**: s3.hhlab.home.arpa:9000
- **Bucket**: spark-homelab
- **Path Style Access**: Enabled (MinIO requirement)
- **Credentials**: Templated from nix-cluster-private

## Troubleshooting

### Operator Fails to Start

Check image availability for ARM64:
```bash
kubectl describe pod -n spark <operator-pod>
```

Look for ImagePullBackOff or architecture mismatch errors.

**Solution**: The operator image should support ARM64. If not, see the INVESTIGATION.md for custom build instructions.

### Jobs Stuck in Pending

Check resource quota:
```bash
kubectl describe resourcequota spark-quota -n spark
```

Check node capacity:
```bash
kubectl describe nodes | grep -A5 "Allocated resources"
```

**Solution**: Reduce executor count or memory in SparkApplication spec.

### History Server Shows No Jobs

Check S3 connectivity:
```bash
kubectl logs -n spark deployment/spark-history-server | grep s3a
```

Test S3 endpoint:
```bash
kubectl exec -n spark <history-pod> -- curl http://s3.hhlab.home.arpa:9000
```

Verify bucket exists:
```bash
# From any pod with aws-cli
kubectl run -n spark -it --rm s3-test --image=amazon/aws-cli --restart=Never -- \
  s3 --endpoint-url=http://s3.hhlab.home.arpa:9000 ls s3://spark-homelab/
```

**Solution**: Verify MinIO credentials in secret, check bucket exists, ensure network connectivity.

### Executors Not Scheduling

Check node labels:
```bash
kubectl get nodes --show-labels | grep arch
```

All nodes should have `kubernetes.io/arch=arm64`.

Check executor pod events:
```bash
kubectl describe pod -n spark <executor-pod>
```

**Solution**: Verify nodeSelector in SparkApplication matches node labels.

## Upgrading

### Spark Operator

Update chart version in `spark-operator/kustomization.yaml`:

```yaml
helmCharts:
  - name: spark-kubernetes-operator
    version: 1.7.0  # Update version
```

Re-vendor chart:
```bash
cd kubernetes/apps/spark/spark-operator
helm pull spark-operator/spark-kubernetes-operator --version 1.7.0
tar -xzf spark-kubernetes-operator-1.7.0.tgz
rm -rf charts/spark-kubernetes-operator
mv spark-kubernetes-operator charts/
rm spark-kubernetes-operator-1.7.0.tgz
```

Apply update:
```bash
nix run .#render-spark | kubectl apply -f -
```

### Spark Runtime

Update image tag in SparkApplication specs:

```yaml
spec:
  image: "apache/spark:3.6.0"  # Update version
  sparkVersion: "3.6.0"
```

## Performance Tuning

### Executor Sizing

For Raspberry Pi 4 (8GB RAM, 4 cores):

**Conservative (default):**
- Memory: 512MB per executor
- Cores: 1 per executor
- Instances: 2-4 executors per job

**Aggressive:**
- Memory: 1GB per executor
- Cores: 2 per executor
- Instances: 8-10 executors (approaching quota)

**Formula:**
- Total executor memory = instances × (memory + 10% overhead)
- Total CPU = instances × cores
- Must fit within ResourceQuota (20GB, 10 CPU)

### Spark Configuration

Common tuning parameters in SparkApplication `sparkConf`:

```yaml
sparkConf:
  "spark.executor.memoryOverhead": "128m"
  "spark.memory.fraction": "0.8"
  "spark.memory.storageFraction": "0.3"
  "spark.sql.shuffle.partitions": "20"
  "spark.default.parallelism": "8"
```

## Security

### RBAC

- Spark Operator: ClusterRole for SparkApplication management
- History Server: Role limited to pod/service read in spark namespace
- Job ServiceAccounts: Minimal permissions for driver/executor pods

### Network Policies

Not currently implemented. Consider adding NetworkPolicies to restrict:
- Operator to Kubernetes API only
- History Server to S3 endpoint only
- Driver/Executor communication within namespace

### Secrets

MinIO credentials stored as Kubernetes Secret, mounted as environment variables in:
- History Server deployment
- Driver pods (via SparkApplication spec)
- Executor pods (via SparkApplication spec)

## Observability

### Prometheus Metrics

ServiceMonitors scrape metrics from:
- Spark Operator: `http://<operator-pod>:10254/metrics`
- History Server: `http://<history-server>:4040/metrics/prometheus`

Metrics include:
- Operator: CRD reconciliation rates, webhook latency
- History Server: Request rates, UI access patterns

### Logging

- Operator logs: `kubectl logs -n spark deployment/spark-operator -f`
- History Server logs: `kubectl logs -n spark deployment/spark-history-server -f`
- Job driver logs: `kubectl logs -n spark <job-name>-driver -f`
- Job executor logs: `kubectl logs -n spark <job-name>-exec-<N> -f`

## References

- [Spark Operator Documentation](https://apache.github.io/spark-kubernetes-operator/)
- [Spark on Kubernetes Guide](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [SparkApplication CRD Spec](https://github.com/apache/spark-kubernetes-operator/blob/main/docs/api-docs.md)
- [Spark Configuration Reference](https://spark.apache.org/docs/latest/configuration.html)
- [Example SparkApplications](examples/README.md)
- [MinIO S3 Integration](minio-integration/README.md)
