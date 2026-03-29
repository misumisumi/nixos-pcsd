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
        assertion = config.services.linstor.client.enable;
        message = ''
          services.linstor.controller needs services.linstor.client to be enabled.
        '';
      }
    ];

    networking.firewall.allowedTCPPorts = [
      3370
    ];

    environment.systemPackages = [
      pkgs.linstor-controller
    ];

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
