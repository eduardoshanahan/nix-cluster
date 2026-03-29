# Spark Example Applications

This directory contains example SparkApplication manifests for testing and learning.

## Available Examples

### spark-pi.yaml

Classic Spark Pi estimation using Monte Carlo simulation. This is a simple CPU-bound workload ideal for validating cluster functionality.

**Submit:**
```bash
kubectl apply -f kubernetes/apps/spark/examples/spark-pi.yaml
```

**Monitor:**
```bash
# Watch SparkApplication status
kubectl get sparkapplications -n spark -w

# Get detailed status
kubectl describe sparkapplication spark-pi-test -n spark

# View driver logs
kubectl logs -n spark spark-pi-test-driver -f

# Check executor pods
kubectl get pods -n spark | grep spark-pi-test
```

**Expected Output:**
Driver logs should show: `Pi is roughly 3.14...`

### spark-s3-test.yaml

Python-based Pi calculation that tests S3 integration. This validates that event logging to MinIO S3 works correctly.

**Submit:**
```bash
kubectl apply -f kubernetes/apps/spark/examples/spark-s3-test.yaml
```

**Verify S3 Event Logs:**
```bash
# Check MinIO bucket for event logs
kubectl run -n spark -it --rm s3-test --image=amazon/aws-cli --restart=Never -- \
  s3 --endpoint-url=http://__MINIO_ENDPOINT__:9000 \
  ls s3://__MINIO_BUCKET__/spark-events/
```

## Job Lifecycle

1. **Submission**: SparkApplication CRD is created
2. **Operator**: Spark Operator watches CRD and creates driver pod
3. **Driver**: Driver pod starts and requests executor pods
4. **Executors**: Executor pods start and register with driver
5. **Execution**: Job runs, logs written to S3
6. **Completion**: Driver completes, executors terminate
7. **History**: Job appears in History Server UI

## Monitoring Jobs

### CLI Monitoring

```bash
# List all jobs
kubectl get sparkapplications -n spark

# Get job details
kubectl describe sparkapplication <job-name> -n spark

# View driver logs
kubectl logs -n spark <job-name>-driver -f

# View executor logs
kubectl logs -n spark <job-name>-exec-1 -f

# Check resource usage
kubectl top pods -n spark
```

### History Server UI

Access the Spark History Server at: https://spark-history.hhlab.home.arpa

- View completed jobs
- Inspect job stages and tasks
- Analyze executor metrics
- Review event timelines

## Troubleshooting

### Job Stuck in Pending

Check resource quota:
```bash
kubectl describe resourcequota spark-quota -n spark
```

Check node capacity:
```bash
kubectl describe nodes | grep -A5 "Allocated resources"
```

### Driver Fails to Start

Check SparkApplication events:
```bash
kubectl describe sparkapplication <job-name> -n spark
```

Check operator logs:
```bash
kubectl logs -n spark deployment/spark-operator -f
```

### S3 Event Logging Fails

Check S3 credentials:
```bash
kubectl get secret minio-s3-credentials -n spark -o yaml
```

Test S3 connectivity from driver pod:
```bash
kubectl exec -n spark <driver-pod> -- \
  curl http://__MINIO_ENDPOINT__:9000
```

### Executors Not Starting

Check driver logs for executor requests:
```bash
kubectl logs -n spark <job-name>-driver | grep -i executor
```

Check node labels (ARM64):
```bash
kubectl get nodes --show-labels | grep arch
```

## Cleanup

Delete completed jobs:
```bash
# Delete specific job
kubectl delete sparkapplication spark-pi-test -n spark

# Delete all jobs
kubectl delete sparkapplications -n spark --all
```

Note: SparkApplication pods are automatically cleaned up by the operator after completion, but the CRD remains for history unless manually deleted.

## Resource Tuning

For Pi hardware (8GB RAM per node), recommended settings:

**Small Jobs (testing):**
- Driver: 512MB memory, 1 core
- Executors: 512MB memory, 1 core, 2-3 instances

**Medium Jobs (data processing):**
- Driver: 1GB memory, 1-2 cores
- Executors: 1GB memory, 1-2 cores, 3-5 instances

**Large Jobs (max capacity):**
- Driver: 1GB memory, 2 cores
- Executors: 1.5GB memory, 2 cores, 8-10 instances (approaching quota limit)

Always leave headroom for system pods and other workloads. The ResourceQuota enforces a hard limit of 20GB memory and 10 CPU.
