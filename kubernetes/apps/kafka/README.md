# Apache Kafka on Kubernetes

A 3-broker Kafka cluster running in KRaft mode, managed by the Strimzi operator.
Deployed for CCDAK certification study.

## Components

| Component | Namespace | What it does |
|-----------|-----------|--------------|
| Strimzi Operator | `kafka` | Manages `Kafka`, `KafkaNodePool`, `KafkaTopic`, `KafkaUser` CRDs |
| Kafka cluster | `kafka` | 3 combined controller+broker nodes, KRaft, replication factor 3 |
| Schema Registry | `kafka` | Confluent Schema Registry for Avro/JSON/Protobuf schemas |
| Kafka UI | `kafka` | Web UI for browsing topics, messages, consumer groups |

## Cluster Shape

- **Mode**: KRaft (no ZooKeeper)
- **Node pool**: 3 replicas, each pod is both controller and broker
- **Kafka version**: 4.1.1
- **Storage**: 8 Gi `local-path` PVC per broker
- **Internal bootstrap**: `kafka-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **Replication factor**: 3 (topics, offsets, transaction log)
- **Min ISR**: 2

## Deployment

```bash
# Validate private config first
nix run .#validate-private-config

# Render all Kafka manifests
nix run .#render-kafka > /tmp/kafka-manifests.yaml

# Dry-run
kubectl apply --dry-run=client -f /tmp/kafka-manifests.yaml

# Apply CRDs first (they exceed the client-side annotation limit)
kubectl apply --server-side=true \
  -f kubernetes/apps/kafka/strimzi-operator/crds.yaml

# Apply the rest
nix run .#render-kafka | kubectl apply -f -
```

## Verify

```bash
# Operator and cluster pods
kubectl get pods -n kafka

# Kafka cluster status (Ready when all brokers are Running)
kubectl get kafka -n kafka

# Topics
kubectl get kafkatopics -n kafka

# Kafka UI
kubectl get ingress -n kafka
```

Kafka UI is exposed at `https://kafka.<homelab-domain>`.
Schema Registry is in-cluster only at `http://schema-registry.kafka.svc.cluster.local:8081`.

## Producing and Consuming (quick test)

```bash
# Exec into any broker pod
kubectl exec -it -n kafka kafka-combined-0 -- bash

# Produce
kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic

# Consume
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --from-beginning
```

## Schema Registry

```bash
# List schemas
curl http://schema-registry.kafka.svc.cluster.local:8081/subjects

# Register a schema
curl -X POST http://schema-registry.kafka.svc.cluster.local:8081/subjects/test-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"schema": "{\"type\": \"string\"}"}'
```

## Upgrading Strimzi

Update the chart version in `strimzi-operator/kustomization.yaml`, re-vendor
the CRDs from the new chart, then re-apply.

The Kafka version is set in `kafka-cluster/kafka.yaml` under `spec.kafka.version`
and `spec.kafka.metadataVersion`.
