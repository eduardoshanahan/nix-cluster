# Task: strimzi 0.51.0 → 1.0.0 migration: v1beta2 storage version

## Status
raw

## Source Repo
nix-cluster

## Context
kubernetes

## What was attempted

Bump strimzi-kafka-operator Helm chart from 0.51.0 to 1.0.0 in a k3s ARM64 cluster.
Changes: crds.yaml (replaced with 1.0.0 CRD bundle), kustomization.yaml (version bump),
kafka-cluster/kafka.yaml (apiVersion kafka.strimzi.io/v1beta2 → v1 for both
KafkaNodePool and Kafka CRs).

## What worked

- 1.0.0 crds.yaml downloaded from GitHub releases (14.5K lines, v1beta2 gone)
- Strimzi operator deployment updated to quay.io/strimzi/operator:1.0.0
- Kafka broker pods updated to quay.io/strimzi/kafka:1.0.0-kafka-4.1.1
- kafka-ui bumped 1.6.3 → 1.6.4 (trivial patch in same render pass)
- After migration: operator reconciles cleanly, Kafka CR Ready=True, all 3 brokers running

## What failed

Initial `kubectl apply --server-side=true` of 1.0.0 crds.yaml failed with:
  "status.storedVersions[0]: Invalid value: v1beta2: missing from spec.versions"

Root cause: ALL strimzi CRDs (not just kafkas, kafkausers) had v1beta2 in
status.storedVersions. The API server blocks removing a version from spec unless
all objects have been migrated away from that storage version.

Second error after patching storedVersions and applying 1.0.0 CRDs:
  "request to convert CR from an invalid group/version: kafka.strimzi.io/v1beta2"

Root cause: In strimzi 0.51.0, `kafkas.kafka.strimzi.io` had v1 with `storage: false`
and v1beta2 with `storage: true`. So Kafka and KafkaNodePool CRs were ACTUALLY stored
as v1beta2 in etcd despite the spec showing v1 was served. Patching storedVersions to
["v1"] lied to the API server; the real objects were v1beta2 in etcd.

Third error after restoring 0.51.0 CRDs and swapping storage to v1, then applying 1.0.0:
  "request to convert CR TO an invalid group/version: kafka.strimzi.io/v1beta2"

This "TO" (not "FROM") error occurred with --server-side=true. Plain `kubectl apply`
(client-side) succeeded without error.

## Wrong assumptions

- Assumed v1 was the storage version in strimzi 0.51.0 (it was NOT — v1beta2 was storage)
- Assumed patching status.storedVersions would let the 1.0.0 CRDs apply cleanly
  without migrating the actual etcd data
- Assumed --server-side apply would work the same as client-side for CRs after migration

## Reusable insights

### Migration procedure for strimzi v1beta2→v1 storage migration:

1. Check storage version: `kubectl get crd kafkas.kafka.strimzi.io -o jsonpath='{range .spec.versions[*]}{.name}{" storage="}{.storage}{"\n"}{end}'`
   If v1beta2 has storage=true → objects are physically stored as v1beta2 in etcd.

2. Keep the 0.51.0 CRDs applied. Patch them to swap storage:
   `kubectl patch crd <crd> --type=json -p '[{"op":"replace","path":"/spec/versions/0/storage","value":true},{"op":"replace","path":"/spec/versions/1/storage","value":false}]'`
   Do this for ALL 10 strimzi CRDs (kafka, kafkanodepool, kafkauser, kafkatopic,
   kafkabridge, kafkaconnect, kafkaconnector, kafkamirrormaker2, kafkarebalance,
   strimzipodset).

3. Annotate all existing strimzi CRs to force re-write as v1:
   `kubectl -n kafka annotate kafka kafka brain.example/migration-ts="$(date +%s)" --overwrite`
   `kubectl -n kafka annotate kafkanodepool combined brain.example/migration-ts="$(date +%s)" --overwrite`
   `kubectl -n kafka annotate strimzipodset kafka-combined brain.example/migration-ts="$(date +%s)" --overwrite`
   (no KafkaUser/KafkaTopic/KafkaConnect in this setup)

4. Patch ALL strimzi CRD status.storedVersions to ["v1"]:
   `kubectl patch crd <crd> --subresource=status --type=merge -p '{"status":{"storedVersions":["v1"]}}'`

5. Apply 1.0.0 CRDs: `nix run .#render-kafka | kubectl apply --server-side=true --force-conflicts -f -`
   If "TO v1beta2" error persists on the Kafka/KafkaNodePool CRs specifically,
   use plain client-side apply for kafka-cluster/kafka.yaml:
   `kubectl apply -f kubernetes/apps/kafka/kafka-cluster/kafka.yaml`
   Client-side apply succeeds where server-side apply fails in this scenario.

### Critical: strimzi 0.51.0 had v1beta2 as physical storage version

Despite the CRD spec listing v1 as a served version, v1beta2 was the storage version.
Objects created with strimzi 0.51.0 are stored as v1beta2 in etcd. This must be
migrated before applying 1.0.0 CRDs.

### Server-side apply vs client-side apply for migrated strimzi CRs

After the storage migration, `kubectl apply --server-side=true --force-conflicts` returns
"request to convert CR TO an invalid group/version: kafka.strimzi.io/v1beta2" for the
Kafka and KafkaNodePool CRs. Plain `kubectl apply` (client-side) succeeds. Root cause
unclear — possibly a watch/informer issue in the API server during CRD version removal.

## Candidate for promotion
The migration procedure → known-mistakes or runbook for "strimzi storage version migration"
