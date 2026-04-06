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
    mkPackageOption
    ;

  cfg = config.services.linstor.client;
  iniFormat = pkgs.formats.ini { };
in
{
  options.services.linstor.client = {
    enable = mkEnableOption "linstor-client";

    package = mkPackageOption pkgs "linstor-client" { };

    settings = mkOption {
      inherit (iniFormat) type;
      default = { };
      description = ''
        Configuration linstor
      '';
    };
  };

  config = mkIf true {
    environment = {
      systemPackages = [
        cfg.package
      ];
      etc."linstor/linstor-client.conf" = {
        enable = cfg.settings != { };
        source = iniFormat.generate "linstor-client.conf" cfg.settings;
      };
    };
  };
}
