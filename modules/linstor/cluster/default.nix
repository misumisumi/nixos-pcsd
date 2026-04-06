{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (builtins) attrNames;
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    mapAttrs'
    mapAttrsToList
    nameValuePair
    mkEnableOption
    filterAttrs
    mkMerge
    mkOption
    mkOrder
    optional
    types
    ;
  inherit (import ./utils.nix { inherit lib; }) createNode createStoragePool createResourceGroup;

  cfg = config.services.linstor.cluster;

  nodeConfig = types.submodule {
    options = {
      address = mkOption {
        type = types.str;
        default = "";
        description = ''
          Address of the node
        '';
      };
      type = mkOption {
        type = types.enum [
          "controller"
          "auxiliary"
          "combined"
          "satellite"
        ];
        default = "satellite";
        description = ''
          Type of the node
        '';
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Extra arguments to pass to the node create command
        '';
      };
      storagePools = mkOption {
        type = types.attrsOf storagePoolConfig;
        default = { };
      };
    };
  };
  storagePoolConfig = types.submodule (
    { config, ... }:
    {
      options = {
        type = mkOption {
          type = types.enum [
            "diskless"
            "ebs_initiator"
            "file"
            "filethin"
            "lvm"
            "lvmthin"
            "remotespdk"
            "spdk"
            "storagespaces"
            "storagespacesthin"
            "zfs"
            "zfsthin"
          ];
          default = "lvm";
          description = ''
            Type of the storage pool
          '';
        };
        volumeGroup = mkOption {
          type = types.str;
          description = ''
            LVM VG or ZFS pools to use for the storage pool
          '';
        };
        extraArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Extra arguments to pass to the storage pool create command
          '';
        };
        physicalStorage = {
          devices = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Full path to the physical devices
            '';
          };
          provider = mkOption {
            readOnly = true;
            type = types.enum [
              "lvm"
              "lvmthin"
              "zfs"
              "zfsthin"
              "spdk"
            ];
            description = ''
              Provider of the disk for linstor
            '';
          };
          extraArgs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Extra arguments to pass to `linstor physical-storage create-device-pool`
            '';
          };
        };
      };
      config = {
        physicalStorage.provider = config.type;
      };
    }
  );

  resourceGroupConfig = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        default = "";
        description = ''
          Name of the resource group
        '';
      };
      encrypt.enable = mkEnableOption "Whether to encrypt the disk";
      pool = mkOption {
        type = types.str;
        description = ''
          Storage pool to use for the resource group
        '';
      };
      placeCount = mkOption {
        type = types.int;
        default = 3;
        description = ''
          Number of volumes to place in the resource group
        '';
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Extra arguments to pass to the resource group create command
        '';
      };
      extraCmds = mkOption {
        type = types.functionTo types.str;
        default = name: "";
        description = ''
          Extra commands to create the resource group.
        '';
      };
      properties = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = ''
          Properties to set on the resource group
          {
            "FileSystem/Type" = "xfs";
            "FileSystem/User" = "nobody";
            "FileSystem/Group" = "nobody";
          }
        '';
      };
      resources = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                default = "";
                description = ''
                  Name of the resource
                '';
              };
              size = mkOption {
                type = types.str;
                default = "";
                description = ''
                  Size of the resource
                '';
              };
              properties = mkOption {
                type = types.attrsOf types.str;
                default = { };
                description = ''
                  Properties to set on the resource group
                  {
                    "FileSystem/Type" = "xfs";
                    "FileSystem/User" = "nobody";
                    "FileSystem/Group" = "nobody";
                  }
                '';
              };
              extraArgs = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  Extra arguments to pass to the spawn-resources command
                '';
              };
              extraCmds = mkOption {
                type = types.functionTo types.str;
                default = name: "";
                description = ''
                  Extra commands to create the resource group.
                '';
              };
            };
          }
        );
      };
    };
  };

  initScript = pkgs.writeShellApplication {
    name = "init-linstor-cluster";
    runtimeInputs = with pkgs; [
      e2fsprogs
      iputils
      linstor-client
    ];
    text = ''
      echo "Initializing Linstor Cluster"
      ${concatStringsSep "\n" cfg.init.scripts}
      echo "Finished initializing Linstor Cluster"
    '';
  };
in
{
  imports = [
    ./high-avilable.nix
  ];
  options.services.linstor.cluster = {
    init = {
      enable = mkEnableOption "Whether to initialize the cluster on boot";
      service.enable = mkEnableOption "Systemd service to initialize the cluster on boot";
      finalPackage = mkOption {
        type = types.package;
        default = initScript;
        readOnly = true;
        description = ''
          Package to use for the initialization script.
          By default, it uses the linstor-client package, but it can be overridden to e.g. include custom scripts or tools.
        '';
      };
      scripts = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Extra scripts to run on cluster start.
          This can be used to e.g. start the linstor-satellite on the nodes.
        '';
      };
      nodeCheck = {
        wait = mkOption {
          type = types.int;
          default = 5;
          description = ''
            Time to wait for the nodes to be ready before starting the cluster initialization.
          '';
        };
        retry = mkOption {
          type = types.int;
          default = 5;
          description = ''
            Number of times to retry checking for the nodes before giving up.
          '';
        };
      };
    };
    nodes = mkOption {
      type = types.attrsOf nodeConfig;
      default = [ ];
      description = ''
        Configuration linstor
      '';
    };
    resourceGroups = mkOption {
      type = types.listOf resourceGroupConfig;
      default = [ ];
      description = ''
        Resource groups to create
      '';
    };
  };

  config = {
    services.linstor.cluster.init.scripts = mkMerge [
      (
        let
          checking = node: address: ''
            i=0
            until ping -c 1 -W 1 "${address}" >/dev/null 2>&1; do
                i=$((i+1))
                if [ "$i" -ge "$RETRIES" ]; then
                    echo "failed to reach ${node} after $RETRIES tries" >&2
                    ALL_PASSED=0
                    break
                fi
                echo "${node}: retry $i/$RETRIES..."
                sleep "$SLEEP"
            done
            echo "${node} is reachable"
          '';
        in
        mkOrder 50 [
          ''
            RETRIES=${toString cfg.init.nodeCheck.retry}
            SLEEP=${toString cfg.init.nodeCheck.wait}

            ALL_PASSED=1

            ${concatStringsSep "\n" (mapAttrsToList (node: v: checking node v.address) cfg.nodes)}

            if [ "$ALL_PASSED" -ne 1 ]; then
              echo "Not all nodes are reachable, aborting cluster initialization"
              exit 1
            fi
          ''
        ]
      )
      (mkOrder 100 [
        ''
          ${concatStringsSep "\n" (
            mapAttrsToList (
              name: v:
              createNode {
                inherit name;
                inherit (v) address type extraArgs;
              }
            ) cfg.nodes
          )}
        ''
      ])
      (mkOrder 200 [
        ''
          ${concatStringsSep "\n" (
            mapAttrsToList (
              node: v:
              concatStringsSep "\n" (
                mapAttrsToList (
                  name: sp_v:
                  createStoragePool {
                    inherit node name;
                    inherit (sp_v)
                      type
                      volumeGroup
                      physicalStorage
                      extraArgs
                      ;
                  }
                ) v.storagePools
              )
            ) cfg.nodes
          )}
        ''
      ])
      (mkOrder 300 [
        ''
          ${concatMapStringsSep "\n" (
            rg:
            createResourceGroup {
              inherit (rg)
                name
                encrypt
                pool
                placeCount
                extraArgs
                extraCmds
                properties
                resources
                ;
            }
          ) cfg.resourceGroups}
        ''
      ])
    ];

    services.linstor.client.settings = {
      global = {
        controllers = concatStringsSep "," (
          attrNames (filterAttrs (_: v: v.type == "controller" || v.type == "combined") cfg.nodes)
        );
      };
    };
    networking.hosts = mapAttrs' (node: v: nameValuePair v.address [ node ]) cfg.nodes;

    environment.systemPackages = optional cfg.init.enable cfg.init.finalPackage;

    # systemd.services.init-linstor-cluster = {
    #   inherit (cfg.init.service) enable;
    #   description = "Linstor Cluster Initialization";
    #   wants = [ "network-online.target" ];
    #   after = [ "network-online.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   before =
    #     optional cfg.HA.enable "drbd-reactor.service"
    #     ++ optional (
    #       config.services.linstor.controller.enable && !cfg.HA.enable
    #     ) "linstor-controller.service";
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = "${cfg.init.finalPackage}/bin/init-linstor-cluster";
    #     RemainAfterExit = true;
    #   };
    # };
  };
}
