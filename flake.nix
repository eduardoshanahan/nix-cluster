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
              ./nixos/profiles/rpi4-k3s.nix
              {
                networking.hostName = hostName;
                homelab.cluster.nodeRole = role;
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
      in
      {
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
