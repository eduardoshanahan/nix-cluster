# JupyterLab + PySpark

Interactive study environment for Apache Spark 3.5.3.
Runs as a Spark driver in **client mode** — the Jupyter pod is the driver, executors are
launched as pods on the cluster.

## Access

`https://spark-jupyter.<domain>` — authenticate with `JUPYTER_TOKEN` from private config.

## SparkSession setup

Every notebook must create a SparkSession. The `spark-defaults.conf` sets cluster
defaults; you still need to provide three values at session creation:

```python
import os
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("study-session") \
    .config("spark.driver.host", os.environ["POD_IP"]) \
    .config("spark.hadoop.fs.s3a.access.key", os.environ["AWS_ACCESS_KEY_ID"]) \
    .config("spark.hadoop.fs.s3a.secret.key", os.environ["AWS_SECRET_ACCESS_KEY"]) \
    .getOrCreate()

print(f"Spark {spark.version} — UI: {spark.sparkContext.uiWebUrl}")
```

- `POD_IP` — injected via Kubernetes downward API; executors need this to reach the driver
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — from the `minio-s3-credentials` secret

## What spark-defaults.conf sets automatically

| Setting | Value |
|---|---|
| `spark.master` | `k8s://https://kubernetes.default.svc` |
| `spark.submit.deployMode` | `client` |
| `spark.kubernetes.namespace` | `spark` |
| `spark.kubernetes.container.image` | `spark-s3:3.5.3` |
| `spark.executor.instances` | `2` |
| `spark.executor.memory` | `512m` |
| `spark.eventLog.enabled` | `true` |
| `spark.eventLog.dir` | `s3a://<bucket>/spark-events` |

Sessions appear in History Server at `https://spark-history.<domain>`.

## Stopping a session

Always stop the SparkSession when done — this terminates executor pods:

```python
spark.stop()
```

Or restart the notebook kernel (it calls `spark.stop()` on teardown).

## Resource budget

The `spark` namespace quota allows 10 CPU / 20 Gi across all workloads.
With 2 executors at 512 Mi each plus the driver, one session uses ~1.5 Gi.
Avoid running multiple sessions simultaneously.

## Image

Built from `docker/Dockerfile.jupyter` (extends `spark-s3:3.5.3`).
Rebuild and deploy with `docker/build-and-deploy.sh`.
