{
  description = "Declarative NixOS Kubernetes cluster for Raspberry Pi 4 homelab nodes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, nixos-hardware, ... }:
    let
      lib = nixpkgs.lib;

      mkClusterSystem =
        {
          hostName,
          role,
          extraModules ? [ ],
          privateSharedModule ? null,
          privateHostModule ? null,
        }:
        lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {
            inherit inputs self;
          };
          modules =
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
        };

      maybePrivateHost =
        name:
        let
          p = ./. + "/nixos/hosts/private/${name}.nix";
        in
        if builtins.pathExists p then p else null;

      privateSharedOverrides =
        let
          p = ./. + "/nixos/hosts/private/overrides.nix";
        in
        if builtins.pathExists p then p else null;
    in
    {
      nixosConfigurations = {
        rpi4-k3s-generic = mkClusterSystem {
          hostName = "k3s-generic";
          role = "agent";
          privateSharedModule = privateSharedOverrides;
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
        validateCluster = pkgs.writeShellApplication {
          name = "validate-cluster-node";
          text = ''
            set -euo pipefail

            if [ "$#" -ne 1 ]; then
              echo "usage: validate-cluster-node <nixosConfiguration>" >&2
              exit 1
            fi

            node="$1"
            flake_ref="path:$PWD#nixosConfigurations.$node"
            flags_json="$(nix eval "$flake_ref.config.services.k3s.extraFlags" --json)"
            exec_start="$(nix eval "$flake_ref.config.systemd.services.k3s.serviceConfig.ExecStart" --raw)"
            role="$(nix eval "$flake_ref.config.homelab.cluster.nodeRole" --raw)"

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
          runtimeInputs = [ pkgs.nixos-rebuild ];
          text = ''
            set -euo pipefail

            if [ "$#" -lt 2 ]; then
              echo "usage: deploy-cluster-node <nixosConfiguration> <target-host>" >&2
              exit 1
            fi

            node="$1"
            target="$2"

            nixos-rebuild switch \
              --flake "path:$PWD#$node" \
              --target-host "$target"
          '';
        };
      in
      {
        packages.validate-cluster-node = validateCluster;
        packages.deploy-cluster-node = deployNode;

        apps.validate-cluster-node = {
          type = "app";
          program = "${validateCluster}/bin/validate-cluster-node";
        };

        apps.deploy-cluster-node = {
          type = "app";
          program = "${deployNode}/bin/deploy-cluster-node";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.nixfmt-rfc-style
            pkgs.prek
            pkgs.kubectl
            pkgs.k3s
          ];

          shellHook = ''
            echo "Entering nix-cluster dev shell"
          '';
        };
      }
    );
}
