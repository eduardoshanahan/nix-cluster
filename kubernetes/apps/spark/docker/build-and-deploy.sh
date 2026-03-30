#!/usr/bin/env bash
set -euo pipefail

# Build and deploy custom Spark image with S3 support to k3s cluster
# Builds ARM64 image for Raspberry Pi cluster using docker buildx

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="spark-s3"
IMAGE_TAG="3.5.3"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
PLATFORM="linux/arm64"

echo "==> Checking docker buildx availability..."
if ! docker buildx version &>/dev/null; then
    echo "ERROR: docker buildx is not available"
    echo "Please install Docker with buildx support"
    exit 1
fi

echo "==> Setting up QEMU emulation for ARM64..."
docker run --privileged --rm tonistiigi/binfmt --install arm64 >/dev/null 2>&1 || true

echo "==> Creating/using multiarch builder..."
if ! docker buildx inspect multiarch &>/dev/null; then
    docker buildx create --name multiarch --driver docker-container --bootstrap
fi

echo "==> Building custom Spark image with S3 support for ${PLATFORM}..."
docker buildx build \
    --builder=multiarch \
    --platform "${PLATFORM}" \
    --load \
    -t "${FULL_IMAGE}" \
    "${SCRIPT_DIR}"

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
echo "Image ${FULL_IMAGE} built for ${PLATFORM} and deployed to all cluster nodes."
echo ""
echo "The image includes:"
echo "  - hadoop-aws-3.3.4.jar"
echo "  - aws-java-sdk-bundle-1.12.262.jar"
echo ""
echo "SparkApplication manifests in kubernetes/apps/spark/examples/ are already configured"
echo "to use this image with S3 event logging enabled."
echo ""
echo "To test:"
echo "  kubectl apply -f kubernetes/apps/spark/examples/spark-pi.yaml"
echo "  kubectl get sparkapplications -n spark -w"
