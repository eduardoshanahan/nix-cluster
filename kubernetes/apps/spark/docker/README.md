# Custom Spark Docker Image with S3 Support

This directory contains the Dockerfile and build scripts for creating a custom Spark image with S3/MinIO support for the homelab cluster.

## Problem

The base `apache/spark:3.5.3` image does not include the hadoop-aws and AWS SDK JARs required for S3A filesystem access. This prevents Spark applications from writing event logs to MinIO S3.

## Solution

Build a custom Docker image based on `apache/spark:3.5.3` with the required JARs pre-installed:
- `hadoop-aws-3.3.4.jar` - Hadoop S3A filesystem implementation
- `aws-java-sdk-bundle-1.12.262.jar` - AWS SDK for S3 API calls

## Architecture Considerations

**Important**: The nix-cluster runs on Raspberry Pi 4 nodes which use ARM64 (aarch64) architecture. The custom Spark image must be built for ARM64, not AMD64 (x86_64).

If you build on an x86_64 development machine without proper cross-compilation, you'll get "exec format error" when Kubernetes tries to run the container on ARM64 nodes.

## Building and Deploying

### Prerequisites

- **Docker with buildx** (Docker Desktop or Docker Engine 19.03+)
- **QEMU emulation** for ARM64 cross-compilation (automatically set up by script)
- SSH access to cluster nodes (cluster-pi-01 through cluster-pi-05)
- kubectl configured (see `docs/KUBECTL_ACCESS.md`)

### Build and Deploy to Cluster (Recommended)

```bash
cd kubernetes/apps/spark/docker
./build-and-deploy.sh
```

This script will:
1. Check docker buildx availability
2. Set up QEMU emulation for ARM64 architecture
3. Create/use a multi-architecture builder
4. Build the custom Spark image for linux/arm64
5. Save the image to a tar file
6. Import the image to all k3s cluster nodes via SSH
7. Verify the image is available on the cluster

**Why docker buildx?**

The build script uses `docker buildx` to cross-compile ARM64 images on x86_64 hosts:
- `--platform linux/arm64`: Target ARM64 architecture
- `--builder=multiarch`: Uses buildx multi-platform builder
- QEMU emulation allows running ARM64 binaries during build on x86_64 host

### Manual Build (Alternative)

If you prefer to build manually for ARM64:

```bash
# Step 1: Set up QEMU emulation for ARM64
docker run --privileged --rm tonistiigi/binfmt --install arm64

# Step 2: Create buildx builder (if not already exists)
docker buildx create --name multiarch --driver docker-container --bootstrap

# Step 3: Build ARM64 image
docker buildx build \
  --builder=multiarch \
  --platform linux/arm64 \
  --load \
  -t spark-s3:3.5.3 \
  .

# Step 4: Save image to tar
docker save spark-s3:3.5.3 -o spark-s3-3.5.3.tar

# Step 5: Import to each cluster node via SSH pipe (more efficient than scp)
for node in cluster-pi-01 cluster-pi-02 cluster-pi-03 cluster-pi-04 cluster-pi-05; do
    echo "Importing to ${node}..."
    ssh eduardo@${node}.hhlab.home.arpa "sudo k3s ctr images import -" < spark-s3-3.5.3.tar
done

# Clean up
rm spark-s3-3.5.3.tar
```

**Common mistake**: Using `docker build` without `buildx --platform linux/arm64` will create an AMD64 image on x86_64 hosts, which fails on ARM64 cluster with "exec format error".

### Verify Image on Cluster

```bash
# Check image exists on a cluster node
ssh eduardo@cluster-pi-01.hhlab.home.arpa "sudo k3s crictl images | grep spark-s3"

# Expected output:
# docker.io/library/spark-s3   3.5.3   149cafba02fd5   1.24GB

# Verify correct architecture (should show arm64)
ssh eduardo@cluster-pi-01.hhlab.home.arpa "sudo k3s crictl inspecti docker.io/library/spark-s3:3.5.3 | grep -A2 architecture"

# Expected output:
# "architecture": "arm64"
```

## Using the Custom Image

The example manifests in `kubernetes/apps/spark/examples/` are already configured to use the custom `spark-s3:3.5.3` image with S3 event logging enabled.

### Quick Test

```bash
# From nix-cluster directory
cd kubernetes/apps/spark

# Render manifests with MinIO credentials (substitutes __MINIO_BUCKET__ and __MINIO_ENDPOINT__)
nix run .#render-spark > /tmp/spark-manifests.yaml
kubectl apply -f /tmp/spark-manifests.yaml

# Or directly render and substitute example manifests
sed -e 's|__MINIO_BUCKET__|spark-homelab|g' \
    -e 's|__MINIO_ENDPOINT__|minio.hhlab.home.arpa|g' \
    examples/spark-pi.yaml | kubectl apply -f -

# Monitor job
kubectl get sparkapplications -n spark -w

# Check logs
kubectl logs -n spark -l spark-role=driver -f
```

### SparkApplication Configuration Template

For new SparkApplications, use this configuration:

```yaml
apiVersion: spark.apache.org/v1
kind: SparkApplication
metadata:
  name: my-spark-job
  namespace: spark
spec:
  sparkConf:
    # Use custom image with S3 JARs
    spark.kubernetes.container.image: "spark-s3:3.5.3"

    # Enable S3 event logging
    spark.eventLog.enabled: "true"
    spark.eventLog.dir: "s3a://spark-homelab/spark-events"
    spark.hadoop.fs.s3a.endpoint: "http://minio.hhlab.home.arpa:9000"
    spark.hadoop.fs.s3a.path.style.access: "true"
    spark.hadoop.fs.s3a.impl: "org.apache.hadoop.fs.s3a.S3AFileSystem"

  driverSpec:
    podTemplateSpec:
      spec:
        containers:
        - name: spark-kubernetes-driver
          # S3 credentials from secret
          env:
          - name: AWS_ACCESS_KEY_ID
            valueFrom:
              secretKeyRef:
                name: minio-s3-credentials
                key: AWS_ACCESS_KEY_ID
          - name: AWS_SECRET_ACCESS_KEY
            valueFrom:
              secretKeyRef:
                name: minio-s3-credentials
                key: AWS_SECRET_ACCESS_KEY

  executorSpec:
    podTemplateSpec:
      spec:
        containers:
        - name: spark-kubernetes-executor
          # Same credentials for executors
          env:
          - name: AWS_ACCESS_KEY_ID
            valueFrom:
              secretKeyRef:
                name: minio-s3-credentials
                key: AWS_ACCESS_KEY_ID
          - name: AWS_SECRET_ACCESS_KEY
            valueFrom:
              secretKeyRef:
                name: minio-s3-credentials
                key: AWS_SECRET_ACCESS_KEY
```

## Verification

After running a job with S3 logging enabled:

```bash
# Check SparkApplication completed successfully
kubectl get sparkapplication spark-pi-test -n spark

# Check History Server now shows the job
# Open: https://spark-history.hhlab.home.arpa

# Or verify events written to MinIO
ssh eduardo@cluster-pi-01.hhlab.home.arpa
# If you have MinIO client configured:
mc ls homelab-minio/spark-homelab/spark-events/
```

## Maintenance

### Updating Spark Version

To update to a new Spark version:

1. Update the `FROM` line in Dockerfile
2. Verify Hadoop version compatibility (check Spark docs)
3. Update hadoop-aws JAR version if needed
4. Update IMAGE_TAG in build-and-deploy.sh
5. Rebuild and redeploy

### Updating hadoop-aws Version

The hadoop-aws version must match the Hadoop version bundled with Spark:
- Spark 3.5.x uses Hadoop 3.3.4
- Check with: `docker run apache/spark:3.5.3 hadoop version`

## Troubleshooting

### "exec /opt/entrypoint.sh: exec format error"

**Symptoms**: Driver pod crashes immediately with exit code 1, logs show "exec format error"

**Cause**: Image was built for wrong architecture (AMD64 instead of ARM64)

**Solution**:
1. Remove the incorrect image from cluster nodes:
   ```bash
   for node in cluster-pi-{01..05}; do
     ssh eduardo@${node}.hhlab.home.arpa "sudo k3s ctr images rm docker.io/library/spark-s3:3.5.3"
   done
   ```

2. Rebuild for ARM64 using buildx:
   ```bash
   ./build-and-deploy.sh
   ```

3. Verify architecture:
   ```bash
   ssh eduardo@cluster-pi-01.hhlab.home.arpa \
     "sudo k3s crictl inspecti docker.io/library/spark-s3:3.5.3 | grep architecture"
   # Should show: "architecture": "arm64"
   ```

### Docker Buildx Not Available

**Symptoms**: `docker buildx version` fails or command not found

**Solution**:
- **Docker Desktop**: Buildx is included by default (macOS, Windows)
- **Docker Engine on Linux**: Install buildx plugin:
  ```bash
  # Check if buildx is available
  docker buildx version

  # If not, install it (varies by distro)
  # For Ubuntu/Debian with Docker from apt:
  apt-get install docker-buildx-plugin

  # Or download manually:
  mkdir -p ~/.docker/cli-plugins
  curl -SL https://github.com/docker/buildx/releases/download/v0.12.0/buildx-v0.12.0.linux-amd64 \
    -o ~/.docker/cli-plugins/docker-buildx
  chmod +x ~/.docker/cli-plugins/docker-buildx
  ```

### Build Fails - Cannot Download JARs

**Cause**: No internet access on build machine

**Solution**: Download JARs manually from Maven Central and copy into Dockerfile:
```dockerfile
COPY hadoop-aws-3.3.4.jar ${SPARK_HOME}/jars/
COPY aws-java-sdk-bundle-1.12.262.jar ${SPARK_HOME}/jars/
```

### Image Import Fails on Cluster Node

**Cause**: Node doesn't have k3s installed or SSH access issues

**Solution**:
- Verify node role (workers have k3s, control planes have k3s)
- Check SSH key authentication works
- Manually import: `sudo k3s ctr images import /path/to/image.tar`

### Job Still Fails with S3 Logging

**Symptoms**: Exit code 1, driver crashes

**Check**:
1. Image is using custom spark-s3:3.5.3 (not base apache/spark:3.5.3)
2. AWS credentials secret exists: `kubectl get secret minio-s3-credentials -n spark`
3. MinIO bucket exists and is accessible
4. Driver logs: `kubectl logs -n spark <job-name>-0-driver`

### History Server Shows "Connection Refused" to S3

**Cause**: MinIO endpoint not accessible from cluster

**Solution**:
- Verify MinIO is running and accessible
- Test from a pod: `kubectl run -n spark test --rm -it --image=curlimages/curl -- curl http://minio.hhlab.home.arpa:9000`
- Check DNS resolution: `host minio.hhlab.home.arpa`

## References

- [Hadoop AWS Documentation](https://hadoop.apache.org/docs/stable/hadoop-aws/tools/hadoop-aws/index.html)
- [Spark on Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [AWS SDK for Java](https://github.com/aws/aws-sdk-java)
- Maven Central: [hadoop-aws](https://mvnrepository.com/artifact/org.apache.hadoop/hadoop-aws)
- Maven Central: [aws-java-sdk-bundle](https://mvnrepository.com/artifact/com.amazonaws/aws-java-sdk-bundle)
