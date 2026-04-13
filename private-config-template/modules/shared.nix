{ ... }:
{
  homelab.privateConfig.source = "private-config-template";
  homelab.privateConfig.isPlaceholder = true;

  homelab.adminAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLEPUBLICKEY000000000000000000000 operator@example"
  ];

  homelab.domain = "cluster.example.internal";
  homelab.cluster.apiServerEndpoint = "https://cluster-api.cluster.example.internal:6443";
  homelab.nix.trustedBuilderPublicKeys = [
    "pi-node-a:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  ];
  homelab.kubernetes.ingressTlsSecretName = "replace-with-private-tls-secret";
  homelab.kubernetes.metallb.addressPool = "198.51.100.10-198.51.100.20";

  homelab.wikijs.postgresHost = "postgres.internal.example";
  homelab.wikijs.postgresPort = 5433;
  homelab.wikijs.postgresDatabase = "wikijs";
  homelab.wikijs.postgresUser = "wikijs";
  homelab.wikijs.postgresPassword = "CHANGE_ME_WIKIJS_DB_PASSWORD";
  homelab.wikijs.minioEndpoint = "minio.internal.example";
  homelab.wikijs.minioPort = 443;
  homelab.wikijs.minioBucket = "wikijs";
  homelab.wikijs.minioAccessKey = "CHANGE_ME_WIKIJS_MINIO_ACCESS_KEY";
  homelab.wikijs.minioSecretKey = "CHANGE_ME_WIKIJS_MINIO_SECRET_KEY";

  homelab.cluster.clusterToken = "replace-with-a-private-bootstrap-token";
}
