{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkOption
    mkEnableOption
    mkPackageOption
    ;
  cfg = config.services.linstor;
in
{
  #NOTE: don't setting DRBD using drbdadm
  disabledModules = [ "services/network-filesystems/drbd.nix" ];

  options.services.linstor.drbd = {
    package = mkPackageOption pkgs "drbd9-dkms" { };
    reactor.enable = mkEnableOption "Enable the DRBD reactor";
  };

  config =
    (mkIf (cfg.satellite.enable || cfg.controller.enable) {
      environment.systemPackages = [ pkgs.drbd ];

      services.udev.packages = [ pkgs.drbd ];

      boot = {
        extraModulePackages = [
          cfg.drbd.package
        ];
        kernelModules = [
          "drbd"
        ];
      };
    })
    // (mkIf cfg.drbd.reactor.enable {
      systemd.services.drbd-reactor = {
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
    });
}
