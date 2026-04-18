#!/usr/bin/env bash
set -euo pipefail

# Build and deploy custom Spark image with S3 support to k3s cluster
# Builds ARM64 image for Raspberry Pi cluster using docker buildx

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="spark-s3"
JUPYTER_IMAGE_NAME="spark-jupyter"
IMAGE_TAG="3.5.3"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
FULL_JUPYTER_IMAGE="${JUPYTER_IMAGE_NAME}:${IMAGE_TAG}"
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
    -f "${SCRIPT_DIR}/Dockerfile" \
    "${SCRIPT_DIR}"

echo ""
echo "==> Building JupyterLab image for ${PLATFORM}..."
docker buildx build \
    --builder=multiarch \
    --platform "${PLATFORM}" \
    --load \
    -t "${FULL_JUPYTER_IMAGE}" \
    -f "${SCRIPT_DIR}/Dockerfile.jupyter" \
    "${SCRIPT_DIR}"

echo ""
echo "==> Verifying images..."
docker images | grep -E "${IMAGE_NAME}|${JUPYTER_IMAGE_NAME}"

deploy_image() {
    local image="$1"
    local label="$2"
    local TEMP_TAR
    TEMP_TAR=$(mktemp --suffix=.tar)
    # shellcheck disable=SC2064
    trap "rm -f ${TEMP_TAR}" EXIT

    echo ""
    echo "==> Importing ${label} to k3s cluster nodes..."
    docker save "${image}" -o "${TEMP_TAR}"
    echo "Image saved to ${TEMP_TAR} ($(du -h "${TEMP_TAR}" | cut -f1))"

    for node in cluster-node-01 cluster-node-02 cluster-node-03 cluster-node-04 cluster-node-05; do
        echo "  -> Importing to ${node}.internal.example..."
        if ssh "eduardo@${node}.internal.example" "sudo k3s ctr images import -" < "${TEMP_TAR}"; then
            echo "     ✓ Success"
        else
            echo "     ✗ Failed (node might not have k3s installed)"
        fi
    done

    rm -f "${TEMP_TAR}"
    trap - EXIT
}

deploy_image "${FULL_IMAGE}" "${FULL_IMAGE}"
deploy_image "${FULL_JUPYTER_IMAGE}" "${FULL_JUPYTER_IMAGE}"

echo ""
echo "==> Verifying images on cluster-node-01..."
ssh eduardo@cluster-node-01.internal.example "sudo k3s crictl images | grep -E '${IMAGE_NAME}|${JUPYTER_IMAGE_NAME}' || echo 'Images not found'"

echo ""
echo "==> Done!"
echo ""
echo "Images built for ${PLATFORM} and deployed to all cluster nodes:"
echo "  ${FULL_IMAGE}         — batch jobs and executor pods"
echo "  ${FULL_JUPYTER_IMAGE} — interactive JupyterLab study environment"
echo ""
echo "To deploy JupyterLab:"
echo "  nix run .#render-spark | kubectl apply -f -"
echo "  kubectl get pods -n spark -w"
echo ""
echo "To test batch jobs:"
echo "  kubectl apply -f kubernetes/apps/spark/examples/spark-pi.yaml"
echo "  kubectl get sparkapplications -n spark -w"
