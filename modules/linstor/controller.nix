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
    optionalString
    ;
  inherit (lib.types) path;

  cfg = config.services.linstor.controller;
in
{
  options.services.linstor.controller = {
    enable = mkEnableOption "linstor-controller";

    package = mkPackageOption pkgs "linstor-controller" { };
    drbd.package = mkPackageOption pkgs "drbd9-dkms" { };

    webui.enable = mkEnableOption "Enable the LINSTOR WebUI";

    logDir = mkOption {
      type = path;
      default = "/var/log/linstor-controller";
      description = ''
        Log directory for the linstor controller.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.services.linstor.satellite.enable;
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

    boot = {
      extraModulePackages = [
        config.services.linstor.controller.drbd.package
      ];
      kernelModules = [
        "drbd"
      ];
    };

    networking.firewall.allowedTCPPorts = [
      3370
    ];

    services.lvm.enable = true;

    systemd.services.linstor-controller = {
      description = "LINSTOR Controller Service";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      startLimitIntervalSec = 20;
      startLimitBurst = 5;
      serviceConfig = {
        Type = "notify";
        #TODO: services.linstor.clientから設定するか、対話形式で変更可能かを制御できるようにする
        ExecStart =
          "${pkgs.linstor-controller}/bin/Controller --logs=${cfg.logDir} --config-directory=/etc/linstor"
          + optionalString cfg.webui.enable " --webui-directory=${pkgs.linstor-gui}/ui";
        SuccessExitStatus = "0 143 129"; # if killed by signal 143 -> SIGTERM, 129 -> SIGHUP
        PrivateTmp = true;
        TimeoutStartSec = 240;
      };
    };
  };
}
