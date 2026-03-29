{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
let
  version = "1.11.0";
in
rustPlatform.buildRustPackage {
  pname = "drbd-reactor";
  inherit version;
  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "drbd-reactor";
    tag = "v${version}";
    hash = "sha256-eg9hRqGYVpXWjcp7anzUKleeDyygur/zaycXr0YQ2ME=";
  };
  cargoHash = "sha256-XoYRl5xRe3bPI3NWR3G5bPLqHD1MFfFYkNjfJm1KaSI=";

  meta = with lib; {
    description = "Monitors DRBD resources via plugins.";
    homepage = "https://github.com/LINBIT/drbd-reactor";
    license = licenses.apsl20;
    platforms = platforms.linux;
  };
}
