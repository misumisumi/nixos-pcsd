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
    mkPackageOption
    mkForce
    ;

  cfg = config.services.linstor.gateway;
in
{
  options.services.linstor.gateway = {
    enable = mkEnableOption "linstor-gateway";

    package = mkPackageOption pkgs "linstor-gateway" { };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.linstor.satellite.enable;
        message = ''
          services.linstor.gateway needs services.linstor.satellite to be enabled.
        '';
      }
    ];

    boot = {
      kernelModules = [
        "nvmet"
      ];
    };

    services = {
      linstor.drbd.reactor.enable = true;
      nfs.server.enable = true;
    };
    #NOTE: linstor-gateway need nfs-server.service, it needs to be loaded, but not started.
    systemd.services.nfs-server.wantedBy = mkForce [ ];
    systemd.services.linstor-gateway = {
      description = "LINSTOR Gateway Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.linstor-gateway}/bin/linstor-gateway server";
      };
    };
  };
}
