rec {
  nixConfig = {
    extra-substituters = [ "https://pcsd.cachix.org" ];
    extra-trusted-public-keys = [
      "pcsd.cachix.org-1:PS4IaaAiEdfaffVlQf/veW+H5T1RAncqNhxJzW9v9Lc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
          pacemaker = import ./modules/pacemaker.nix self;
          pcsd = import ./modules self nixConfig;
          default = self.nixosModules.pcsd;
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
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
            config.allowUnfree = true;
          };
          packages = {
            inherit (pkgs)
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
          };
          checks = { };
        };
    };
}
# let
#   perSystem =
#     attrs:
#     nixpkgs.lib.genAttrs (import systems) (
#       system:
#       attrs (
#         import nixpkgs {
#           inherit system;
#           overlays = [ self.overlays.default ];
#         }
#       )
#     );
# in
# {
#   packages = perSystem (pkgs: rec {
#     default = pcs;
#     docs = pkgs.callPackage ./docs { inherit self; };

#     inherit (pkgs)
#       pcs
#       pcs-web-ui
#       pacemaker
#       resource-agents
#       ocf-resource-agents
#       linstor-controller
#       linstor-satellite
#       linstor-client
#       linstor-gui
#       ;
#     inherit (pkgs.python3Packages) linstor-api-py pyagentx;
#   });

#   overlays = {
#     pcsd = import ./pkgs;
#     default = self.overlays.pcsd;
#   };

#   formatter = perSystem (pkgs: pkgs.alejandra);

#   devShells = perSystem (pkgs: {
#     update = pkgs.mkShell {
#       packages = with pkgs; [
#         alejandra
#         git
#         bundler
#         bundix

#         (writeShellApplication {
#           name = "updateGems";
#           runtimeInputs = [
#             bundler
#             bundix
#           ];

#           text = ''
#             cd ./pkgs/pcs || exit
#             rm Gemfile.lock gemset.nix
#             bundler
#             bundix
#           '';
#         })

#         common-updater-scripts
#         jq
#         nix-prefetch-git
#         nix-prefetch-github
#         nix-prefetch-scripts
#         nix-update
#       ];
#     };

#     docs =
#       let
#         inputs = with pkgs; [
#           git
#           nix
#           mkdocs
#           ghp-import
#           python3Packages.mkdocs-material
#           python3Packages.pygments
#         ];
#       in
#       pkgs.mkShell {
#         packages = [
#           (pkgs.writeShellApplication {
#             name = "localDeploy";
#             runtimeInputs = inputs;
#             text = "(nix build --option binary-caches \"https://cache.nixos.org\" .#docs && cd result && mkdocs serve)";
#           })

#           (pkgs.writeShellApplication {
#             name = "ghDeploy";
#             runtimeInputs = inputs;
#             text = builtins.readFile ./docs/deploy.sh;
#           })
#         ]
#         ++ inputs;
#       };
#   });
# };
# }
