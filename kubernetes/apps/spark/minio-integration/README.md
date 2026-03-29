# MinIO S3 Integration for Spark

## Overview

This directory contains the MinIO S3 credentials used by Spark jobs and the History Server for event logging and data I/O.

## S3 Configuration

- **Endpoint**: `__MINIO_ENDPOINT__` (port 9000)
- **Bucket**: `spark-homelab`
- **Path Style Access**: Enabled (required for MinIO)
- **Event Logs Path**: `s3a://spark-homelab/spark-events/`

## Prerequisites

Before deploying Spark, ensure the following on your MinIO instance:

1. **Create Bucket**: Create a bucket named `spark-homelab`
2. **Create Access Key**: Generate a dedicated access key for Spark with read/write permissions to the bucket
3. **Update nix-cluster-private**: Add the credentials to the private configuration

## Updating Credentials

Credentials are templated from `nix-cluster-private/modules/shared.nix`:

```nix
homelab.spark.minioAccessKey = "your-access-key";
homelab.spark.minioSecretKey = "your-secret-key";
homelab.spark.minioEndpoint = "minio.hhlab.home.arpa";
homelab.spark.minioBucket = "spark-homelab";
```

After updating, re-render and apply:

```bash
nix run .#render-spark | kubectl apply -f -
```

## Testing S3 Connectivity

Test S3 access from within the cluster:

```bash
kubectl run -n spark -it --rm s3-test --image=amazon/aws-cli --restart=Never -- \
  s3 --endpoint-url=http://minio.hhlab.home.arpa:9000 ls s3://spark-homelab/
```
