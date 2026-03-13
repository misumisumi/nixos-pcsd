{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (builtins) dirOf;
  inherit (lib)
    mkEnableOption
    mkIf
    mkPackageOption
    mkOption
    ;
  # inherit (lib.types) str;

  cfg = config.services.linstor.client;
in
{
  options.services.linstor.client = {
    enable = mkEnableOption "linstor-client";

    package = mkPackageOption pkgs "linstor-client" { };

    # config = mkOption {
    #   type = str;
    #   default = "";
    #   description = ''
    #     Configuration linstor
    #   '';
    # };
  };

  config = mkIf true {
    assertions = [
      {
        assertion = config.services.linstor.controller.enable;
        message = ''
          Enabling services.linstor.controller.enable requires a services.linstor.client configuration.
        '';
      }
    ];

    environment.systemPackages = [
      cfg.package
    ];
  };
}
