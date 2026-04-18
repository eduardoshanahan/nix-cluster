{
  description = "Declarative NixOS Kubernetes cluster for Raspberry Pi 4 homelab nodes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    private.url = "path:./private-config-template";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      nixos-hardware,
      private,
      ...
    }:
    let
      lib = nixpkgs.lib;
      privateModuleOrNull = name: lib.attrByPath [ "nixosModules" name ] null private;

      mkClusterModules =
        {
          hostName,
          role,
          extraModules ? [ ],
          privateSharedModule ? null,
          privateHostModule ? null,
        }:
        [
          nixos-hardware.nixosModules.raspberry-pi-4
          ./nixos/modules/options.nix
          ./nixos/modules/base.nix
          ./nixos/modules/ssh.nix
          ./nixos/modules/k3s-common.nix
          ./nixos/modules/validation.nix
          ./nixos/profiles/rpi4-base.nix
          (if role == "server" then ./nixos/profiles/k3s-server.nix else ./nixos/profiles/k3s-agent.nix)
          {
            networking.hostName = hostName;
          }
        ]
        ++ extraModules
        ++ lib.optionals (privateSharedModule != null) [ privateSharedModule ]
        ++ lib.optionals (privateHostModule != null) [ privateHostModule ];

      mkClusterSystemFor =
        system: args:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs self;
          };
          modules = mkClusterModules args;
        };

      mkClusterSystem = mkClusterSystemFor "aarch64-linux";

      maybePrivateHost = name: privateModuleOrNull name;

      privateSharedOverrides = privateModuleOrNull "default";
    in
    {
      nixosConfigurations = {
        rpi4-k3s-generic = mkClusterSystem {
          hostName = "cluster-bootstrap";
          role = "agent";
          privateSharedModule = privateSharedOverrides;
          extraModules = [
            {
              homelab.cluster.enable = false;
            }
          ];
        };

        cluster-node-01 = mkClusterSystem {
          hostName = "cluster-node-01";
          role = "server";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-node-01";
          extraModules = [ ./nixos/hosts/cluster-node-01.nix ];
        };

        cluster-node-02 = mkClusterSystem {
          hostName = "cluster-node-02";
          role = "server";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-node-02";
          extraModules = [ ./nixos/hosts/cluster-node-02.nix ];
        };

        cluster-node-03 = mkClusterSystem {
          hostName = "cluster-node-03";
          role = "server";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-node-03";
          extraModules = [ ./nixos/hosts/cluster-node-03.nix ];
        };

        cluster-node-04 = mkClusterSystem {
          hostName = "cluster-node-04";
          role = "agent";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-node-04";
          extraModules = [ ./nixos/hosts/cluster-node-04.nix ];
        };

        cluster-node-05 = mkClusterSystem {
          hostName = "cluster-node-05";
          role = "agent";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-node-05";
          extraModules = [ ./nixos/hosts/cluster-node-05.nix ];
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        validatePrivateConfig = pkgs.writeShellApplication {
          name = "validate-private-config";
          runtimeInputs = [
            pkgs.jq
            pkgs.nix
          ];
          text = ''
            set -euo pipefail

            quiet=0

            usage() {
              cat >&2 <<'EOF'
            usage: validate-private-config [--quiet] [nixosConfiguration]

              --quiet  Only print failures.

            Validates that a real private flake exists and that path-based
            evaluation resolves the required private values.
            EOF
              exit 1
            }

            while [ "$#" -gt 0 ]; do
              case "$1" in
                --quiet)
                  quiet=1
                  shift
                  ;;
                --help|-h)
                  usage
                  ;;
                --*)
                  echo "unknown option: $1" >&2
                  usage
                  ;;
                *)
                  break
                  ;;
              esac
            done

            if [ "$#" -gt 1 ]; then
              usage
            fi

            node="''${1:-cluster-node-01}"
            flake_ref="path:$PWD#nixosConfigurations.$node"
            private_flake_dir="''${NIX_CLUSTER_PRIVATE_FLAKE:-$PWD/../nix-cluster-private}"

            if [ ! -f "$private_flake_dir/flake.nix" ]; then
              cat >&2 <<EOF
            missing private flake: $private_flake_dir/flake.nix

            Create a sibling nix-cluster-private flake there, or point
            NIX_CLUSTER_PRIVATE_FLAKE at the real private flake location.

            The tracked template lives at:
              $PWD/private-config-template
            EOF
              exit 1
            fi

            private_override_args=(--no-write-lock-file --override-input private "path:$private_flake_dir")
            private_source="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.privateConfig.source" --raw)"
            private_placeholder="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.privateConfig.isPlaceholder" --json)"

            if [ "$private_placeholder" = "true" ]; then
              echo "private config check failed: private flake source '$private_source' is still the placeholder template" >&2
              exit 1
            fi

            cluster_token_json="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.cluster.clusterToken" --json)"
            admin_keys_json="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.adminAuthorizedKeys" --json)"
            builder_keys_json="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.nix.trustedBuilderPublicKeys" --json)"
            domain="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.domain" --raw)"

            if [ "$cluster_token_json" = "null" ]; then
              echo "private config check failed: homelab.cluster.clusterToken is null for $node" >&2
              exit 1
            fi

            if ! printf '%s' "$admin_keys_json" | jq -e 'length > 0' >/dev/null; then
              echo "private config check failed: homelab.adminAuthorizedKeys is empty for $node" >&2
              exit 1
            fi

            if ! printf '%s' "$builder_keys_json" | jq -e 'length > 0' >/dev/null; then
              echo "private config check failed: homelab.nix.trustedBuilderPublicKeys is empty for $node" >&2
              exit 1
            fi

            if [ "$quiet" -eq 0 ]; then
              echo "private config OK for $node"
              echo "private_source=$private_source"
              echo "domain=$domain"
              echo "admin_keys=$(printf '%s' "$admin_keys_json" | jq 'length')"
              echo "trusted_builder_keys=$(printf '%s' "$builder_keys_json" | jq 'length')"
            fi
          '';
        };
        sessionPreflight = pkgs.writeShellApplication {
          name = "session-preflight";
          runtimeInputs = [ pkgs.ripgrep ];
          text = ''
            set -euo pipefail

            repo_root="$PWD"
            kb_root="''${HHLAB_WIKI_DIR:-$repo_root/../hhlab-wiki}"

            required_repo_docs=(
              "$repo_root/README.md"
              "$repo_root/HOMELAB_AND_CLUSTER_CONTEXT.md"
              "$repo_root/docs/RESTART_PLAN.md"
              "$repo_root/docs/LESSONS_LEARNED.md"
            )

            required_kb_docs=(
              "$kb_root/README.md"
              "$kb_root/indexes/by-repo.md"
              "$kb_root/indexes/by-topic.md"
              "$kb_root/indexes/by-date.md"
            )

            echo "nix-cluster session pre-flight"
            echo "repo_root=$repo_root"
            echo "kb_root=$kb_root"
            echo

            missing=0
            for file in "''${required_repo_docs[@]}"; do
              if [ -f "$file" ]; then
                echo "OK   $file"
              else
                echo "MISS $file" >&2
                missing=1
              fi
            done

            for file in "''${required_kb_docs[@]}"; do
              if [ -f "$file" ]; then
                echo "OK   $file"
              else
                echo "MISS $file" >&2
                missing=1
              fi
            done

            if [ "$missing" -ne 0 ]; then
              cat >&2 <<'EOF'

Pre-flight failed: required docs are missing.
Set HHLAB_WIKI_DIR if your private wiki lives outside ../hhlab-wiki.
EOF
              exit 1
            fi

            echo
            echo "Relevant KB entries for nix-cluster:"
            rg -n "nix-cluster|nix-cluster-private" "$kb_root/indexes/by-repo.md" || true

            echo
            cat <<'EOF'
Next required steps:
1. Read the linked KB records.
2. Summarize grounded assumptions and open uncertainties.
3. Validate plan against decisions and anti-patterns before implementation.
EOF
          '';
        };
        bootstrapImage =
          (mkClusterSystemFor system {
            hostName = "cluster-bootstrap";
            role = "agent";
            privateSharedModule = privateSharedOverrides;
            extraModules = [
              {
                homelab.cluster.enable = false;
              }
            ];
          }).config.system.build.sdImage;
        validateCluster = pkgs.writeShellApplication {
          name = "validate-cluster-node";
          runtimeInputs = [ validatePrivateConfig ];
          text = ''
            set -euo pipefail

            if [ "$#" -ne 1 ]; then
              echo "usage: validate-cluster-node <nixosConfiguration>" >&2
              exit 1
            fi

            node="$1"
            validate-private-config --quiet "$node"
            private_flake_dir="''${NIX_CLUSTER_PRIVATE_FLAKE:-$PWD/../nix-cluster-private}"
            private_override_args=(--no-write-lock-file --override-input private "path:$private_flake_dir")
            flake_ref="path:$PWD#nixosConfigurations.$node"
            flags_json="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.services.k3s.extraFlags" --json)"
            exec_start="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.systemd.services.k3s.serviceConfig.ExecStart" --raw)"
            role="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.cluster.nodeRole" --raw)"

            echo "role=$role"
            echo "flags=$flags_json"
            echo "exec_start=$exec_start"

            if [ "$role" = "server" ]; then
              if ! printf '%s\n' "$flags_json" | grep -q 'write-kubeconfig-mode'; then
                echo "validation failed: server node is missing --write-kubeconfig-mode" >&2
                exit 1
              fi
              if ! printf '%s\n' "$exec_start" | grep -q '/bin/k3s server'; then
                echo "validation failed: server node does not generate k3s server ExecStart" >&2
                exit 1
              fi
            else
              if printf '%s\n' "$flags_json" | grep -q 'write-kubeconfig-mode'; then
                echo "validation failed: worker node contains --write-kubeconfig-mode" >&2
                exit 1
              fi
              if ! printf '%s\n' "$exec_start" | grep -q '/bin/k3s agent'; then
                echo "validation failed: worker node does not generate k3s agent ExecStart" >&2
                exit 1
              fi
            fi
          '';
        };
        deployNode = pkgs.writeShellApplication {
          name = "deploy-cluster-node";
          runtimeInputs = [
            pkgs.nixos-rebuild
            validatePrivateConfig
          ];
          text = ''
            set -euo pipefail

            ssh_opts=''${NIX_CLUSTER_SSHOPTS:-"-F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5"}
            build_host=''${NIX_CLUSTER_BUILD_HOST:-}
            self_build=0

            usage() {
              cat >&2 <<'EOF'
            usage: deploy-cluster-node [--build-host <host>] [--self-build] <nixosConfiguration> <target-host>

              --build-host <host>  Build on a remote ARM builder before deploying.
              --self-build         Build on the target host itself.

            Environment:
              NIX_CLUSTER_BUILD_HOST  Default remote builder host if --build-host is not passed.
              NIX_CLUSTER_SSHOPTS     SSH options exported to NIX_SSHOPTS.
            EOF
              exit 1
            }

            while [ "$#" -gt 0 ]; do
              case "$1" in
                --build-host)
                  [ "$#" -ge 2 ] || usage
                  build_host="$2"
                  shift 2
                  ;;
                --self-build)
                  self_build=1
                  shift
                  ;;
                --help|-h)
                  usage
                  ;;
                --*)
                  echo "unknown option: $1" >&2
                  usage
                  ;;
                *)
                  break
                  ;;
              esac
            done

            if [ "$#" -ne 2 ]; then
              usage
            fi

            node="$1"
            target="$2"

            validate-private-config --quiet "$node"
            private_flake_dir="''${NIX_CLUSTER_PRIVATE_FLAKE:-$PWD/../nix-cluster-private}"

            if [ "$self_build" -eq 1 ]; then
              build_host="$target"
            fi

            export NIX_SSHOPTS="$ssh_opts"

            rebuild_cmd=(
              /run/current-system/sw/bin/nixos-rebuild
              switch
              --no-write-lock-file
              --flake "path:$PWD#$node"
              --override-input private "path:$private_flake_dir"
              --target-host "$target"
              --sudo
            )

            if [ -n "$build_host" ]; then
              rebuild_cmd+=(--build-host "$build_host")
            fi

            "''${rebuild_cmd[@]}"
          '';
        };
        renderTemplatedKustomize =
          {
            name,
            relativePath,
          }:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [
              pkgs.findutils
              pkgs.gnused
              pkgs.kubectl
              pkgs.kubernetes-helm
              pkgs.nix
              validatePrivateConfig
            ];
            text = ''
              set -euo pipefail

              private_flake_dir="''${NIX_CLUSTER_PRIVATE_FLAKE:-$PWD/../nix-cluster-private}"
              private_override_args=(--no-write-lock-file --override-input private "path:$private_flake_dir")
              flake_ref="path:$PWD#nixosConfigurations.cluster-node-01"

              validate-private-config --quiet cluster-node-01

              domain="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.domain" --raw)"
              ingress_tls_secret_name="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.kubernetes.ingressTlsSecretName" --raw)"
              metallb_address_pool="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.kubernetes.metallb.addressPool" --raw)"

              if [ "$ingress_tls_secret_name" = "replace-with-private-tls-secret" ]; then
                echo "render failed: set homelab.kubernetes.ingressTlsSecretName in nix-cluster-private" >&2
                exit 1
              fi

              if [ "$metallb_address_pool" = "198.51.100.10-198.51.100.20" ]; then
                echo "render failed: set homelab.kubernetes.metallb.addressPool in nix-cluster-private" >&2
                exit 1
              fi

              tmpdir="$(mktemp -d)"
              trap 'rm -rf "$tmpdir"' EXIT
              render_root="$tmpdir/render"

              cp -R "$PWD/kubernetes" "$render_root"

              headlamp_host="headlamp.$domain"
              kube_state_metrics_host="kube-state-metrics.$domain"
              namespace_label_prefix="homelab.$domain"
              traefik_load_balancer_ip="''${metallb_address_pool%%-*}"

              while IFS= read -r -d $'\0' file; do
                sed -i \
                  -e "s|__HEADLAMP_HOST__|$headlamp_host|g" \
                  -e "s|__KUBE_STATE_METRICS_HOST__|$kube_state_metrics_host|g" \
                  -e "s|__INGRESS_TLS_SECRET_NAME__|$ingress_tls_secret_name|g" \
                  -e "s|__METALLB_ADDRESS_POOL__|$metallb_address_pool|g" \
                  -e "s|__TRAEFIK_LOAD_BALANCER_IP__|$traefik_load_balancer_ip|g" \
                  -e "s|__HOMELAB_NAMESPACE_LABEL_PREFIX__|$namespace_label_prefix|g" \
                  "$file"
              done < <(find "$render_root" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

              exec kubectl kustomize --enable-helm "$render_root/${relativePath}"
            '';
          };
        renderObservability = pkgs.writeShellApplication {
          name = "render-observability";
          relativePath = "platform/observability";
        };
        renderPlatform = renderTemplatedKustomize {
          name = "render-platform";
          relativePath = "platform";
        };
        renderHeadlamp = renderTemplatedKustomize {
          name = "render-headlamp";
          relativePath = "operations";
        };
        renderSpark = pkgs.writeShellApplication {
          name = "render-spark";
          runtimeInputs = [
            pkgs.findutils
            pkgs.gnused
            pkgs.jq
            pkgs.kubectl
            pkgs.kubernetes-helm
            pkgs.nix
            validatePrivateConfig
          ];
          text = ''
            set -euo pipefail

            private_flake_dir="''${NIX_CLUSTER_PRIVATE_FLAKE:-$PWD/../nix-cluster-private}"
            private_override_args=(--no-write-lock-file --override-input private "path:$private_flake_dir")
            flake_ref="path:$PWD#nixosConfigurations.cluster-node-01"

            validate-private-config --quiet cluster-node-01

            domain="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.domain" --raw)"
            ingress_tls_secret_name="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.kubernetes.ingressTlsSecretName" --raw)"
            minio_endpoint="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.spark.minioEndpoint" --raw)"
            minio_bucket="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.spark.minioBucket" --raw)"
            minio_access_key="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.spark.minioAccessKey" --raw)"
            minio_secret_key="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.spark.minioSecretKey" --raw)"

            if [ "$ingress_tls_secret_name" = "replace-with-private-tls-secret" ]; then
              echo "render failed: set homelab.kubernetes.ingressTlsSecretName in nix-cluster-private" >&2
              exit 1
            fi

            if [ "$minio_access_key" = "CHANGE_ME_ACCESS_KEY" ]; then
              echo "render failed: set homelab.spark.minioAccessKey in nix-cluster-private" >&2
              exit 1
            fi

            if [ "$minio_secret_key" = "CHANGE_ME_SECRET_KEY" ]; then
              echo "render failed: set homelab.spark.minioSecretKey in nix-cluster-private" >&2
              exit 1
            fi

            tmpdir="$(mktemp -d)"
            trap 'rm -rf "$tmpdir"' EXIT
            render_root="$tmpdir/render"

            cp -R "$PWD/kubernetes" "$render_root"

            spark_history_server_host="spark-history.$domain"
            spark_operator_host="spark-operator.$domain"
            namespace_label_prefix="homelab.$domain"

            while IFS= read -r -d $'\0' file; do
              sed -i \
                -e "s|__SPARK_HISTORY_SERVER_HOST__|$spark_history_server_host|g" \
                -e "s|__SPARK_OPERATOR_HOST__|$spark_operator_host|g" \
                -e "s|__INGRESS_TLS_SECRET_NAME__|$ingress_tls_secret_name|g" \
                -e "s|__HOMELAB_NAMESPACE_LABEL_PREFIX__|$namespace_label_prefix|g" \
                -e "s|__DOMAIN__|$domain|g" \
                -e "s|__MINIO_ENDPOINT__|$minio_endpoint|g" \
                -e "s|__MINIO_BUCKET__|$minio_bucket|g" \
                -e "s|__MINIO_ACCESS_KEY__|$minio_access_key|g" \
                -e "s|__MINIO_SECRET_KEY__|$minio_secret_key|g" \
                "$file"
            done < <(find "$render_root" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

            exec kubectl kustomize --enable-helm "$render_root/apps/spark"
          '';
        };
        renderWikiJS = pkgs.writeShellApplication {
          name = "render-wikijs";
          runtimeInputs = [
            pkgs.findutils
            pkgs.gnused
            pkgs.kubectl
            pkgs.kubernetes-helm
            pkgs.nix
            validatePrivateConfig
          ];
          text = ''
            set -euo pipefail

            private_flake_dir="''${NIX_CLUSTER_PRIVATE_FLAKE:-$PWD/../nix-cluster-private}"
            private_override_args=(--no-write-lock-file --override-input private "path:$private_flake_dir")
            flake_ref="path:$PWD#nixosConfigurations.cluster-node-01"

            validate-private-config --quiet cluster-node-01

            domain="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.domain" --raw)"
            ingress_tls_secret_name="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.kubernetes.ingressTlsSecretName" --raw)"
            postgres_host="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.postgresHost" --raw)"
            postgres_port="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.postgresPort" --json | jq -r '.')"
            postgres_database="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.postgresDatabase" --raw)"
            postgres_user="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.postgresUser" --raw)"
            postgres_password="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.postgresPassword" --raw)"
            minio_endpoint="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.minioEndpoint" --raw)"
            minio_port="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.minioPort" --json | jq -r '.')"
            minio_bucket="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.minioBucket" --raw)"
            minio_access_key="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.minioAccessKey" --raw)"
            minio_secret_key="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.wikijs.minioSecretKey" --raw)"

            if [ "$ingress_tls_secret_name" = "replace-with-private-tls-secret" ]; then
              echo "render failed: set homelab.kubernetes.ingressTlsSecretName in nix-cluster-private" >&2
              exit 1
            fi

            if [ "$postgres_password" = "CHANGE_ME_WIKIJS_DB_PASSWORD" ]; then
              echo "render failed: set homelab.wikijs.postgresPassword in nix-cluster-private" >&2
              exit 1
            fi

            if [ "$minio_access_key" = "CHANGE_ME_WIKIJS_MINIO_ACCESS_KEY" ]; then
              echo "render failed: set homelab.wikijs.minioAccessKey in nix-cluster-private" >&2
              exit 1
            fi

            if [ "$minio_secret_key" = "CHANGE_ME_WIKIJS_MINIO_SECRET_KEY" ]; then
              echo "render failed: set homelab.wikijs.minioSecretKey in nix-cluster-private" >&2
              exit 1
            fi

            tmpdir="$(mktemp -d)"
            trap 'rm -rf "$tmpdir"' EXIT
            render_root="$tmpdir/render"

            cp -R "$PWD/kubernetes" "$render_root"

            wikijs_host="wiki.$domain"
            namespace_label_prefix="homelab.$domain"

            while IFS= read -r -d $'\0' file; do
              sed -i \
                -e "s|__WIKIJS_HOST__|$wikijs_host|g" \
                -e "s|__INGRESS_TLS_SECRET_NAME__|$ingress_tls_secret_name|g" \
                -e "s|__HOMELAB_NAMESPACE_LABEL_PREFIX__|$namespace_label_prefix|g" \
                -e "s|__DOMAIN__|$domain|g" \
                -e "s|__WIKIJS_POSTGRES_HOST__|$postgres_host|g" \
                -e "s|__WIKIJS_POSTGRES_PORT__|$postgres_port|g" \
                -e "s|__WIKIJS_POSTGRES_DATABASE__|$postgres_database|g" \
                -e "s|__WIKIJS_POSTGRES_USER__|$postgres_user|g" \
                -e "s|__WIKIJS_POSTGRES_PASSWORD__|$postgres_password|g" \
                -e "s|__WIKIJS_MINIO_ENDPOINT__|$minio_endpoint|g" \
                -e "s|__WIKIJS_MINIO_PORT__|$minio_port|g" \
                -e "s|__WIKIJS_MINIO_BUCKET__|$minio_bucket|g" \
                -e "s|__WIKIJS_MINIO_ACCESS_KEY__|$minio_access_key|g" \
                -e "s|__WIKIJS_MINIO_SECRET_KEY__|$minio_secret_key|g" \
                "$file"
            done < <(find "$render_root" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

            exec kubectl kustomize --enable-helm "$render_root/apps/wikijs"
          '';
        };
        renderKafka = pkgs.writeShellApplication {
          name = "render-kafka";
          runtimeInputs = [
            pkgs.findutils
            pkgs.gnused
            pkgs.kubectl
            pkgs.kubernetes-helm
            pkgs.nix
            validatePrivateConfig
          ];
          text = ''
            set -euo pipefail

            private_flake_dir="''${NIX_CLUSTER_PRIVATE_FLAKE:-$PWD/../nix-cluster-private}"
            private_override_args=(--no-write-lock-file --override-input private "path:$private_flake_dir")
            flake_ref="path:$PWD#nixosConfigurations.cluster-node-01"

            validate-private-config --quiet cluster-node-01

            domain="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.domain" --raw)"
            ingress_tls_secret_name="$(nix eval "''${private_override_args[@]}" "$flake_ref.config.homelab.kubernetes.ingressTlsSecretName" --raw)"

            if [ "$ingress_tls_secret_name" = "replace-with-private-tls-secret" ]; then
              echo "render failed: set homelab.kubernetes.ingressTlsSecretName in nix-cluster-private" >&2
              exit 1
            fi

            tmpdir="$(mktemp -d)"
            trap 'rm -rf "$tmpdir"' EXIT
            render_root="$tmpdir/render"

            cp -R "$PWD/kubernetes" "$render_root"

            kafka_ui_host="kafka-ui.$domain"
            namespace_label_prefix="homelab.$domain"

            while IFS= read -r -d $'\0' file; do
              sed -i \
                -e "s|__KAFKA_UI_HOST__|$kafka_ui_host|g" \
                -e "s|__INGRESS_TLS_SECRET_NAME__|$ingress_tls_secret_name|g" \
                -e "s|__HOMELAB_NAMESPACE_LABEL_PREFIX__|$namespace_label_prefix|g" \
                -e "s|__DOMAIN__|$domain|g" \
                "$file"
            done < <(find "$render_root" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

            exec kubectl kustomize --enable-helm "$render_root/apps/kafka"
          '';
        };
      in
      {
        packages.bootstrap-sd-image = bootstrapImage;
        packages.validate-private-config = validatePrivateConfig;
        packages.session-preflight = sessionPreflight;
        packages.validate-cluster-node = validateCluster;
        packages.deploy-cluster-node = deployNode;
        packages.render-platform = renderPlatform;
        packages.render-observability = renderObservability;
        packages.render-headlamp = renderHeadlamp;
        packages.render-spark = renderSpark;
        packages.render-wikijs = renderWikiJS;
        packages.render-kafka = renderKafka;

        apps.validate-private-config = {
          type = "app";
          program = "${validatePrivateConfig}/bin/validate-private-config";
        };

        apps.session-preflight = {
          type = "app";
          program = "${sessionPreflight}/bin/session-preflight";
        };

        apps.validate-cluster-node = {
          type = "app";
          program = "${validateCluster}/bin/validate-cluster-node";
        };

        apps.deploy-cluster-node = {
          type = "app";
          program = "${deployNode}/bin/deploy-cluster-node";
        };

        apps.render-platform = {
          type = "app";
          program = "${renderPlatform}/bin/render-platform";
        };

        apps.render-observability = {
          type = "app";
          program = "${renderObservability}/bin/render-observability";
        };

        apps.render-headlamp = {
          type = "app";
          program = "${renderHeadlamp}/bin/render-headlamp";
        };

        apps.render-spark = {
          type = "app";
          program = "${renderSpark}/bin/render-spark";
        };

        apps.render-wikijs = {
          type = "app";
          program = "${renderWikiJS}/bin/render-wikijs";
        };

        apps.render-kafka = {
          type = "app";
          program = "${renderKafka}/bin/render-kafka";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.gitleaks
            pkgs.deadnix
            pkgs.nixfmt-rfc-style
            pkgs.prek
            pkgs.kubectl
            pkgs.kubectx
            pkgs.k9s
            pkgs.kustomize
            pkgs.kubernetes-helm
            pkgs.k3s
            pkgs.stern
          ];

          shellHook = ''
            echo "Entering nix-cluster dev shell"
          '';
        };
      }
    );
}
