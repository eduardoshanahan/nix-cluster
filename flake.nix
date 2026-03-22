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

        cluster-pi-01 = mkClusterSystem {
          hostName = "cluster-pi-01";
          role = "server";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-pi-01";
          extraModules = [ ./nixos/hosts/cluster-pi-01.nix ];
        };

        cluster-pi-02 = mkClusterSystem {
          hostName = "cluster-pi-02";
          role = "server";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-pi-02";
          extraModules = [ ./nixos/hosts/cluster-pi-02.nix ];
        };

        cluster-pi-03 = mkClusterSystem {
          hostName = "cluster-pi-03";
          role = "server";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-pi-03";
          extraModules = [ ./nixos/hosts/cluster-pi-03.nix ];
        };

        cluster-pi-04 = mkClusterSystem {
          hostName = "cluster-pi-04";
          role = "agent";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-pi-04";
          extraModules = [ ./nixos/hosts/cluster-pi-04.nix ];
        };

        cluster-pi-05 = mkClusterSystem {
          hostName = "cluster-pi-05";
          role = "agent";
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "cluster-pi-05";
          extraModules = [ ./nixos/hosts/cluster-pi-05.nix ];
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

            node="''${1:-cluster-pi-01}"
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
              flake_ref="path:$PWD#nixosConfigurations.cluster-pi-01"

              validate-private-config --quiet cluster-pi-01

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
      in
      {
        packages.bootstrap-sd-image = bootstrapImage;
        packages.validate-private-config = validatePrivateConfig;
        packages.validate-cluster-node = validateCluster;
        packages.deploy-cluster-node = deployNode;
        packages.render-platform = renderPlatform;
        packages.render-observability = renderObservability;
        packages.render-headlamp = renderHeadlamp;

        apps.validate-private-config = {
          type = "app";
          program = "${validatePrivateConfig}/bin/validate-private-config";
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
