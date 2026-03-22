rec {
  nixConfig = {
    extra-substituters = [ "https://pcsd.cachix.org" ];
    extra-trusted-public-keys = [
      "pcsd.cachix.org-1:PS4IaaAiEdfaffVlQf/veW+H5T1RAncqNhxJzW9v9Lc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
      ];
      flake = {
        nixosModules = {
          linstor = import ./modules/linstor;
          pacemaker = import ./modules/pacemaker.nix;
          pcsd = import ./modules/pcsd.nix;
          default = import ./modules;
        };
        overlay = self.overlays.default;
        overlays.default = import ./pkgs;
      };
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      perSystem =
        {
          system,
          pkgs,
          lib,
          ...
        }:
        rec {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
            config.allowUnfree = true;
          };
          # docs = pkgs.callPackage ./docs { inherit self; };
          # formatter = pkgs.nix-fmt;

          packages = {
            inherit (pkgs)
              drbd9-dkms
              fence-agents
              linstor-client
              linstor-controller
              linstor-gui
              linstor-satellite
              ocf-resource-agents
              pacemaker
              pcs
              pcs-web-ui
              resource-agents
              ;
            inherit (pkgs.python3Packages) linstor-api-py pyagentx;
            update-pkgs = import ./update-pkgs.nix {
              inherit lib;
              inherit (pkgs) writeShellScriptBin nix-update;
              myPkgs = packages;
            };
          };
          checks = packages;
          devshells = {
            update = {
              packages = with pkgs; [
                git
                bundler
                bundix

                common-updater-scripts
                jq
                nix-prefetch-git
                nix-prefetch-github
                nix-prefetch-scripts
                nix-update
              ];
            };

            docs =
              let
                inputs = with pkgs; [
                  git
                  nix
                  mkdocs
                  ghp-import
                  python3Packages.mkdocs-material
                  python3Packages.pygments
                ];
              in
              {
                packages = [
                  (pkgs.writeShellApplication {
                    name = "localDeploy";
                    runtimeInputs = inputs;
                    text = "(nix build --option binary-caches \"https://cache.nixos.org\" .#docs && cd result && mkdocs serve)";
                  })

                  (pkgs.writeShellApplication {
                    name = "ghDeploy";
                    runtimeInputs = inputs;
                    text = builtins.readFile ./docs/deploy.sh;
                  })
                ]
                ++ inputs;
              };
          };
        };
    };
}
