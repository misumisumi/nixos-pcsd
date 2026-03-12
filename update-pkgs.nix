{
  lib,
  myPkgs,
  writeShellScriptBin,
  nix-update,
  ...
}:
let
  inherit (lib)
    filterAttrs
    concatStringsSep
    mapAttrsToList
    ;
  pkgs = filterAttrs (
    pname: value: !(value.passthru.updateSkip or false) && (pname != "update-pkgs")
  ) myPkgs;
in
writeShellScriptBin "update-pkgs" ''
  set -euo pipefail

  ${concatStringsSep "\n" (
    mapAttrsToList (
      pname: value:
      let
        options = concatStringsSep " " (value.passthru.updateOptions or [ ]);
      in
      ''
        echo "Updating ${pname}..."
        ${nix-update}/bin/nix-update --flake ${pname} ${options} "$@"
      ''
    ) pkgs
  )}
''
