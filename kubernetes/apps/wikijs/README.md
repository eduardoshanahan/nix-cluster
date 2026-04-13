# Wiki.js on Kubernetes

This directory contains the first-pass Wiki.js deployment for the homelab
cluster.

## Hosting model

- Wiki.js runs in-cluster as a normal application workload.
- Traefik exposes it at `wiki.<homelab-domain>`.
- PostgreSQL stays on Synology shared infra at `postgres.<homelab-domain>:5433`.
- Uploaded assets are intended to live in Synology MinIO rather than on a
  cluster PVC.

This keeps the cluster workload mostly stateless while still letting us start
using the cluster for a real internal service.

## Current deployment shape

- namespace: `wikijs`
- workload: one `Deployment` replica
- service: `ClusterIP`
- ingress: standard Kubernetes `Ingress` for Traefik
- image: `ghcr.io/requarks/wiki:2.5.300`

## Private config contract

The render helper expects these private values in
`../nix-cluster-private/modules/shared.nix`:

```nix
homelab.wikijs.postgresHost = "postgres.<domain>";
homelab.wikijs.postgresPort = 5433;
homelab.wikijs.postgresDatabase = "wikijs";
homelab.wikijs.postgresUser = "wikijs";
homelab.wikijs.postgresPassword = "<db-password>";
homelab.wikijs.minioEndpoint = "minio.<domain>";
homelab.wikijs.minioPort = 443;
homelab.wikijs.minioBucket = "wikijs";
homelab.wikijs.minioAccessKey = "<minio-access-key>";
homelab.wikijs.minioSecretKey = "<minio-secret-key>";
```

## Synology-side prerequisites

Before applying the manifests for real, provision the shared infra pieces on
Synology:

1. Create the PostgreSQL role and database for Wiki.js.
2. Create the MinIO bucket and app-specific access key.

Example PostgreSQL bootstrap:

```bash
psql -h postgres.<domain> -p 5433 -U postgres -d postgres -c "CREATE ROLE wikijs LOGIN PASSWORD '<strong-password>';"
psql -h postgres.<domain> -p 5433 -U postgres -d postgres -c "CREATE DATABASE wikijs OWNER wikijs;"
```

## Render and apply

```bash
nix run .#render-wikijs > /tmp/wikijs-manifests.yaml
kubectl apply --dry-run=client -f /tmp/wikijs-manifests.yaml
nix run .#render-wikijs | kubectl apply -f -
```

## Initial setup and asset storage

On first boot, finish the Wiki.js setup wizard in the browser.

After the initial admin login, configure the storage module in the Wiki.js
Administration Area to use the rendered MinIO values stored in the
`wikijs-runtime-config` secret:

```bash
kubectl -n wikijs get secret wikijs-runtime-config -o jsonpath='{.data.MINIO_ENDPOINT}' | base64 -d; echo
kubectl -n wikijs get secret wikijs-runtime-config -o jsonpath='{.data.MINIO_BUCKET}' | base64 -d; echo
kubectl -n wikijs get secret wikijs-runtime-config -o jsonpath='{.data.MINIO_ACCESS_KEY}' | base64 -d; echo
```

Recommended MinIO storage settings:

- endpoint: the rendered `MINIO_ENDPOINT`
- port: the rendered `MINIO_PORT`
- bucket: the rendered `MINIO_BUCKET`
- path-style access: enabled
- SSL/TLS: enabled when using the HTTPS MinIO FQDN

## Validation goals

- `kubectl get pods -n wikijs` shows the deployment healthy.
- `kubectl get ingress -n wikijs` shows the `wiki.<homelab-domain>` route.
- The first-run setup page loads at `https://wiki.<homelab-domain>`.
- Saving and fetching a test asset works after enabling MinIO storage in the UI.
