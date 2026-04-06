{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOrder
    mkMerge
    mkForce
    mkOption
    mkEnableOption
    types
    optionals
    ;

  cfg = config.services.linstor.cluster.HA;
  tomlFormat = pkgs.formats.toml { };

  inherit (import ./utils.nix { inherit lib; }) createResourceGroup;
in
{
  options.services.linstor.cluster.HA = {
    enable = mkEnableOption "linstor cluster HA resource";
    resourceGroup = {
      name = mkOption {
        type = types.str;
        default = "linstor-db-grp";
        description = ''
          Name of the resource group to create for the HA resource.
        '';
      };
      pool = mkOption {
        type = types.str;
        description = ''
          Name of the pool to create for the HA resource.
        '';
      };
      placeCount = mkOption {
        type = types.int;
        default = 3;
        description = ''
          Number of volumes to place in the resource group
        '';
      };
      extraCmds = mkOption {
        type = types.functionTo types.str;
        default = name: ''
          linstor resource-group drbd-options \
            --auto-promote=no \
            --quorum=majority \
            --on-suspended-primary-outdated=force-secondary \
            --on-no-quorum=io-error \
            --on-no-data-accessible=io-error \
            ${name}
        '';
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ "--diskless-on-remaining true" ];
        description = ''
          Extra arguments to pass to the resource group create command
        '';
      };
      properties = mkOption {
        type = types.attrsOf types.str;
        default = {
        };
        description = ''
          Properties to set on the resource group
        '';
      };
      resource = {
        name = mkOption {
          type = types.str;
          default = "linstor_db";
          description = ''
            Name of the resource
          '';
        };
        size = mkOption {
          type = types.str;
          default = "200M";
          description = ''
            Size of the resource
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
    };
  };
  config = mkIf cfg.enable {
    environment.etc."drbd-reactor.d/linstor_db.toml".source = tomlFormat.generate "linstor_db.toml" {
      "promoter" = [
        {
          resources = {
            linstor_db = {
              start = [
                "var-lib-linstor.mount"
                "linstor-controller.service"
              ];
            };
          };
        }
      ];
    };
    services.linstor = {
      cluster.init.scripts = optionals config.services.linstor.cluster.init.enable (mkMerge [
        (mkOrder 80 [
          ''
            isHAConfigured=0
            if [ "$(systemctl is-active var-lib-linstor.mount)" == "active" ]; then
              echo "HA linstor cluster already configured, skipping initialization"
              isHAConfigured=1
            else
              find /run/systemd/system/linstor-controller.service.d -type f -name "*.conf" -exec mv {} {}.bak \;
              find /run/systemd/system/var-lib-linstor.mount.d/ -type f -name "*.conf" -exec mv {} {}.bak \;
              systemctl start linstor-controller

              if [ "$(systemctl is-active linstor-controller)" != "active" ]; then
                echo "Failed to start linstor-controller"
                exit 1
              fi
            fi
          ''
        ])
        (mkOrder 250 [
          ''
            # Only create the resource group if it doesn't exist yet, otherwise we might mess up an already running cluster
            if [[ $isHAConfigured -eq 0 ]]; then
            ${createResourceGroup {
              resources = [ cfg.resourceGroup.resource ];
              inherit (cfg.resourceGroup)
                name
                pool
                placeCount
                properties
                extraArgs
                extraCmds
                ;
            }}

              systemctl stop linstor-controller

              mv /var/lib/linstor /var/lib/linstor.bak
              mkdir /var/lib/linstor

              chattr +i /var/lib/linstor
              ${pkgs.drbd}/bin/drbdadm primary ${cfg.resourceGroup.resource.name} --force
              mkfs.ext4 /dev/drbd/by-res/${cfg.resourceGroup.resource.name}/0

              systemctl start var-lib-linstor.mount
              cp -r /var/lib/linstor.bak/* /var/lib/linstor/
              systemctl start linstor-controller

              find /run/systemd/system/linstor-controller.service.d -type f -name "*.conf.bak" -exec sh -c 'mv "$0" "''${0%.bak}"' {} \;
              find /run/systemd/system/var-lib-linstor.mount.d/ -type f -name "*.conf.bak" -exec sh -c 'mv "$0" "''${0%.bak}"' {} \;
            fi
          ''
        ])

      ]);
      drbd.reactor.enable = true;
    };
    #NOTE: var-lib-linstor.mount is started by drbd-reactor
    systemd.mounts = [
      {
        name = "var-lib-linstor.mount";
        unitConfig = {
          Description = "Filesystem for the LINSTOR controller";
        };
        what = "/dev/drbd/by-res/${cfg.resourceGroup.resource.name}/0";
        where = "/var/lib/linstor";
      }
    ];
  };
}
