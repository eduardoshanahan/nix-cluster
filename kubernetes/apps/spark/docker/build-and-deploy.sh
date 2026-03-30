#!/usr/bin/env bash
set -euo pipefail

# Build and deploy custom Spark image with S3 support to k3s cluster

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="spark-s3"
IMAGE_TAG="3.5.3"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo "==> Building custom Spark image with S3 support..."
docker build -t "${FULL_IMAGE}" "${SCRIPT_DIR}"

echo ""
echo "==> Verifying image..."
docker images | grep "${IMAGE_NAME}"

echo ""
echo "==> Importing image to k3s cluster nodes..."
echo "This will save the image and import it to all cluster nodes."

# Save image to tar
TEMP_TAR=$(mktemp --suffix=.tar)
trap "rm -f ${TEMP_TAR}" EXIT

docker save "${FULL_IMAGE}" -o "${TEMP_TAR}"
echo "Image saved to ${TEMP_TAR} ($(du -h ${TEMP_TAR} | cut -f1))"

# Import to all cluster nodes
for node in cluster-pi-01 cluster-pi-02 cluster-pi-03 cluster-pi-04 cluster-pi-05; do
    echo "  -> Importing to ${node}.hhlab.home.arpa..."
    if ssh "eduardo@${node}.hhlab.home.arpa" "sudo k3s ctr images import -" < "${TEMP_TAR}"; then
        echo "     ✓ Success"
    else
        echo "     ✗ Failed (node might not have k3s installed)"
    fi
done

echo ""
echo "==> Verifying image on cluster nodes..."
echo "Checking cluster-pi-01..."
ssh eduardo@cluster-pi-01.hhlab.home.arpa "sudo k3s crictl images | grep '${IMAGE_NAME}' || echo 'Image not found'"

echo ""
echo "==> Done!"
echo ""
echo "Next steps:"
echo "1. Update SparkApplication manifests to use: ${FULL_IMAGE}"
echo "2. Uncomment S3 event logging configuration in sparkConf"
echo "3. Uncomment AWS credentials in driverSpec/executorSpec"
echo ""
echo "Example sparkConf:"
echo "  spark.kubernetes.container.image: \"${FULL_IMAGE}\""
echo "  spark.eventLog.enabled: \"true\""
echo "  spark.eventLog.dir: \"s3a://spark-homelab/spark-events\""
