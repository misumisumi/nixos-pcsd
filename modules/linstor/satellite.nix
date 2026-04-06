{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    mkOverride
    mkPackageOption
    optionalString
    types
    ;

  cfg = config.services.linstor.satellite;
  tomlFormat = pkgs.formats.ini { };
in
{
  options.services.linstor.satellite = {
    enable = mkEnableOption "linstor-satellite";

    package = mkPackageOption pkgs "linstor-satellite" { };

    logDir = mkOption {
      type = types.path;
      default = "/var/log/linstor-satellite";
      description = ''
        Log directory for the linstor satellite.
      '';
    };
    settings = mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = ''
        Configuration for the linstor satellite.
        This can be used to e.g. set the satellite name or the controller address.
        {
          encrypt = {
            passphrase="@passphrase@";
          };
        }
      '';
    };
    secretsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File consisting of lines of the form `varname=value`
        to define variables for the linstor configuration.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.linstor.client.enable;
        message = ''
          services.linstor.controller needs services.linstor.client to be enabled.
        '';
      }
    ];

    environment.etc = {
      "lvm/lvm.conf".text = ''
        devices {
          global_filter = [ "r|^/dev/drbd|", "r|^/dev/mapper/[lL]instor|" ]
        }
      '';
    };

    networking.firewall = {
      allowedTCPPortRanges = [
        #NOTE: TcpPortAutoRange property default value, that show to linstor controller set-property --help
        {
          from = 7000;
          to = 7999;
        }
      ];
      allowedTCPPorts = [
        3366
        3367
      ];
    };

    services.lvm = {
      enable = true;
      boot = {
        thin.enable = true;
        vdo.enable = false;
      };
    };
    #NOTE: vdocalculatesize --help returns 1 on nixos 25.11 so we can't use upstream NixOS Modules.
    boot = {
      initrd = {
        kernelModules = [ "dm-vdo" ];

        systemd.initrdBin = mkIf config.boot.initrd.services.lvm.enable [ pkgs.vdo ];

        extraUtilsCommands = mkIf (!config.boot.initrd.systemd.enable) ''
          ls ${pkgs.vdo}/bin/ | while read BIN; do
            copy_bin_and_libs ${pkgs.vdo}/bin/$BIN
          done
          substituteInPlace $out/bin/vdorecover --replace "${pkgs.bash}/bin/bash" "/bin/sh"
          substituteInPlace $out/bin/adaptlvm --replace "${pkgs.bash}/bin/bash" "/bin/sh"
        '';

        extraUtilsCommandsTest = mkIf (!config.boot.initrd.systemd.enable) ''
          exclude='adaptlvm|vdorecover|vdocalculatesize'
          ls ${pkgs.vdo}/bin/ | grep -vE "($exclude)" | while read BIN; do
            $out/bin/$(basename $BIN) --version > /dev/null
          done
        '';
      };
    };
    services.lvm.package = mkOverride 999 pkgs.lvm2_vdo; # this overrides mkDefault
    environment.systemPackages = [ pkgs.vdo ];

    systemd.services.linstor-satellite =
      let
        replaceSecrets = secretFile: out: ''
          while read -r line; do
            key=$(echo "$line" | cut -d= -f1)
            value=$(echo "$line" | cut -d= -f2-)
            ${pkgs.replace-secret}/bin/replace-secret "@$key@" "$value" ${out}
          done < ${secretFile}
        '';
        preStart = pkgs.writeShellScript "linstor-satellite-prestart" ''
          install -Dm644 ${tomlFormat.generate "linstor.toml" cfg.settings} /etc/linstor/linstor.toml
          ${optionalString (
            cfg.secretsFile != null
          ) "${replaceSecrets cfg.secretsFile "/etc/linstor/linstor.toml"}"}
        '';
      in
      {
        description = "LINSTOR Satellite Service";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        startLimitIntervalSec = 60;
        startLimitBurst = 10;
        serviceConfig = {
          Environment = optionalString config.services.linstor.cluster.HA.enable "LS_KEEP_RES=${config.services.linstor.cluster.HA.resourceGroup.resource.name}";
          Type = "simple";
          ExecStartPre = "!${preStart}";
          ExecStart = "${pkgs.linstor-satellite}/bin/Satellite --logs=${cfg.logDir} --config-directory=/etc/linstor";
          KillMode = "mixed"; # send SIGTERM only to satellite, send SIGKILL to all spawned processes
          PrivateTmp = true;
          SuccessExitStatus = "0 143 129"; # if killed by signal 143 -> SIGTERM, 129 -> SIGHUP
          TimeoutStartSec = 70;
          User = "root";
        };
      };
  };
}
