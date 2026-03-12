{
  pkgs ? import <nixpkgs> { },
}:
{
  inherit (pkgs.callPackage ./pkgs/linstor-server { }) linstor-controller;
}
