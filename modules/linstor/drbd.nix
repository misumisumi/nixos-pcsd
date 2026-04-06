{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkForce
    mkIf
    mkOption
    mkPackageOption
    optional
    types
    ;
  cfg = config.services.linstor;
  tomlFormat = pkgs.formats.toml { };
in
{
  #NOTE: don't setting DRBD using drbdadm
  disabledModules = [ "services/network-filesystems/drbd.nix" ];

  options.services.linstor.drbd = {
    package = mkPackageOption pkgs "drbd9-dkms" { };
    config = mkOption {
      type = types.lines;
      default = ''
        include "/etc/drbd.d/global_common.conf";
        include "/etc/drbd.d/*.res";
      '';
      description = ''
        Configuration drbd
      '';
    };
    reactor = {
      enable = mkEnableOption "Enable the DRBD reactor";
      settings = mkOption {
        inherit (tomlFormat) type;
        default = {
          snippets = "/etc/drbd-reactor.d";
          snippets-monitoring-interval = 120;
          statistics-poll-interval = 60;
          # log = {
          #   level = "warn";
          #   file = "/var/log/drbd-reactor.log";
          # };
        };
        description = ''
          Configuration linstor
        '';
      };
    };
  };

  config = mkIf cfg.satellite.enable {
    environment = {
      systemPackages = [ pkgs.drbd ] ++ optional cfg.drbd.reactor.enable pkgs.drbd-reactor;
      etc = {
        "drbd.conf".text = cfg.drbd.config;
        "drbd.d/global_common.conf".source = "${pkgs.drbd}/etc/drbd.d/global_common.conf";
        "drbd.d/linstor-resources.res".text = ''
          include "/var/lib/linstor.d/*.res";
        '';
        "drbd-reactor.toml" = {
          inherit (cfg.drbd.reactor) enable;
          source = tomlFormat.generate "drbd-reactor.toml" cfg.drbd.reactor.settings;
        };
      };
    };
    services.udev.packages = [ pkgs.drbd ];

    boot = {
      extraModulePackages = [
        cfg.drbd.package
      ];
      kernelModules = [
        "drbd"
      ];
    };

    systemd = {
      packages = [ pkgs.drbd ];
      services = {
        #NOTE: Linstor controller service start by drbd-reactor
        linstor-controller.wantedBy = mkForce [ ];

        drbd-reactor = {
          inherit (cfg.drbd.reactor) enable;
          description = "DRBD-Reactor Service";
          wantedBy = [ "multi-user.target" ];
          wants = [
            "dbus.service"
            "polkit.service"
          ];
          requires = [ "network-online.target" ];
          after = [
            "dbus.service"
            "network-online.target"
            "polkit.service"
            "snmpd.service"
          ];

          unitConfig = {
            ConditionKernelCommandLine = "!nocluster";
          };
          serviceConfig = {
            Type = "notify";
            ExecStart = "${pkgs.drbd-reactor}/bin/drbd-reactor";
            ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          };
        };
        drbd-reactor-reload = {
          inherit (cfg.drbd.reactor) enable;
          description = "Reload drbd-reactor on plugin changes";
          wantedBy = [ "multi-user.target" ];
          after = [ "drbd-reactor.service" ];
          startLimitIntervalSec = 0;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemctl reload drbd-reactor.service";
          };
        };
      };
      paths.drbd-reactor-reload = {
        inherit (cfg.drbd.reactor) enable;
        description = "Description=Reload drbd-reactor on plugin changes";
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          TriggerLimitIntervalSec = 0;
          PathChanged = /etc/drbd-reactor.d;
        };
      };
    };
  };
}
