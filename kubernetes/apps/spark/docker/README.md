# Custom Spark Docker Image with S3 Support

This directory contains the Dockerfile and build scripts for creating a custom Spark image with S3/MinIO support for the homelab cluster.

## Problem

The base `apache/spark:3.5.3` image does not include the hadoop-aws and AWS SDK JARs required for S3A filesystem access. This prevents Spark applications from writing event logs to MinIO S3.

## Solution

Build a custom Docker image based on `apache/spark:3.5.3` with the required JARs pre-installed:
- `hadoop-aws-3.3.4.jar` - Hadoop S3A filesystem implementation
- `aws-java-sdk-bundle-1.12.262.jar` - AWS SDK for S3 API calls

## Building and Deploying

### Prerequisites

- Docker installed on build machine (requires internet access to download JARs)
- SSH access to cluster nodes (cluster-pi-01 through cluster-pi-05)
- kubectl configured (see `docs/KUBECTL_ACCESS.md`)

### Build and Deploy to Cluster

```bash
cd kubernetes/apps/spark/docker
./build-and-deploy.sh
```

This script will:
1. Build the custom Spark image locally
2. Save the image to a tar file
3. Import the image to all k3s cluster nodes via SSH
4. Verify the image is available on the cluster

### Manual Build (Alternative)

If you prefer to build manually:

```bash
# Build image
docker build -t spark-s3:3.5.3 .

# Save image
docker save spark-s3:3.5.3 -o spark-s3-3.5.3.tar

# Import to each cluster node
for node in cluster-pi-01 cluster-pi-02 cluster-pi-03 cluster-pi-04 cluster-pi-05; do
    scp spark-s3-3.5.3.tar eduardo@${node}.hhlab.home.arpa:/tmp/
    ssh eduardo@${node}.hhlab.home.arpa "sudo k3s ctr images import /tmp/spark-s3-3.5.3.tar"
    ssh eduardo@${node}.hhlab.home.arpa "rm /tmp/spark-s3-3.5.3.tar"
done
```

### Verify Image on Cluster

```bash
# Check image on a cluster node
ssh eduardo@cluster-pi-01.hhlab.home.arpa "sudo k3s crictl images | grep spark-s3"
```

## Using the Custom Image

### Update SparkApplication Manifests

1. Change the container image in sparkConf:
   ```yaml
   sparkConf:
     spark.kubernetes.container.image: "spark-s3:3.5.3"
   ```

2. Uncomment S3 event logging configuration:
   ```yaml
   sparkConf:
     spark.eventLog.enabled: "true"
     spark.eventLog.dir: "s3a://spark-homelab/spark-events"
     spark.hadoop.fs.s3a.endpoint: "http://minio.hhlab.home.arpa:9000"
     spark.hadoop.fs.s3a.path.style.access: "true"
     spark.hadoop.fs.s3a.impl: "org.apache.hadoop.fs.s3a.S3AFileSystem"
   ```

3. Uncomment AWS credentials in driver and executor specs:
   ```yaml
   driverSpec:
     podTemplateSpec:
       spec:
         containers:
         - name: spark-kubernetes-driver
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

### Example: Enable S3 in spark-pi.yaml

```bash
# Edit the example
vim kubernetes/apps/spark/examples/spark-pi.yaml

# Change image line
spark.kubernetes.container.image: "spark-s3:3.5.3"

# Uncomment all S3-related lines (marked with comments)

# Apply
kubectl apply -f kubernetes/apps/spark/examples/spark-pi.yaml
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
