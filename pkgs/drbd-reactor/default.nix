{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  drbd,
  systemd,
}:
let
  pname = "drbd-reactor";
  version = "1.11.0";

  inherit (lib) makeBinPath;
  utils = [
    drbd
    systemd
  ];
in
rustPlatform.buildRustPackage {
  inherit pname version;
  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "drbd-reactor";
    tag = "v${version}";
    hash = "sha256-eg9hRqGYVpXWjcp7anzUKleeDyygur/zaycXr0YQ2ME=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  outputs = [
    "out"
    "doc"
  ];
  cargoHash = "sha256-XoYRl5xRe3bPI3NWR3G5bPLqHD1MFfFYkNjfJm1KaSI=";

  postInstall = ''
    mkdir -p $out/etc/
    mv example/drbd-reactor.toml $out/etc/drbd-reactor.toml

    mkdir -p $doc/share/doc
    cp -r doc $doc/share/doc/${pname}
  '';

  fixupPhase = ''
    runHook preFixup

    while read -r file; do
      wrapProgram "$file" \
        --prefix PATH : ${makeBinPath utils}
    done < <(find $out/bin -type f)

    runHook postFixup
  '';

  meta = with lib; {
    description = "Monitors DRBD resources via plugins.";
    homepage = "https://github.com/LINBIT/drbd-reactor";
    license = licenses.apsl20;
    platforms = platforms.linux;
  };
}
