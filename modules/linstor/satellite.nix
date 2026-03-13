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
    mkOption
    ;
  inherit (lib.types) path;

  cfg = config.services.linstor.satellite;
in
{
  options.services.linstor.satellite = {
    enable = mkEnableOption "linstor-satellite";

    package = mkPackageOption pkgs "linstor-satellite" { };
    logDir = mkOption {
      type = path;
      default = "/var/log/linstor-satellite";
      description = ''
        Log directory for the linstor satellite.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.services.linstor.controller.enable;
        message = ''
          Cannot enable both services.linstor.controller and services.linstor.satellite at the same time.
        '';
      }
      {
        assertion = !config.services.drbd.enable;
        message = ''
          Cannot enable both services.linstor.controller and services.drbd at the same time.
        '';
      }
    ];

    environment.systemPackages = [ pkgs.drbd ];

    services.udev.packages = [ pkgs.drbd ];

    boot.kernelModules = [ "drbd" ];

    networking.firewall.allowedTCPPorts = [
      3366
      3367
    ];

    systemd.services.linstor-satellite = {
      description = "LINSTOR Satellite Service";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      startLimitIntervalSec = 40;
      startLimitBurst = 10;
      serviceConfig = {
        Type = "notify";
        #TODO: services.linstor.clientから設定するか、対話形式で変更可能かを制御できるようにする
        ExecStart = "${pkgs.linstor-satellite}/bin/Satellite --logs=${cfg.logDir} -config-directory=/etc/linstor";
        KillMode = "mixed"; # send SIGTERM only to satellite, send SIGKILL to all spawned processes
        SuccessExitStatus = "0 143 129"; # if killed by signal 143 -> SIGTERM, 129 -> SIGHUP
        PrivateTmp = true;
        TimeoutStartSec = 70;
      };
    };
  };
}
