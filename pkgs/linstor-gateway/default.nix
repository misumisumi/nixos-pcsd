{
  lib,
  buildGoModule,
  makeWrapper,
  fetchFromGitHub,
  nftables,
  nvmet-cli,
  ocf-resource-agents,
  psmisc,
  targetcli-fb,
  iptables ? nftables,
}:
let
  inherit (lib) makeBinPath;

  version = "2.1.0";
  utils = [
    iptables
    nvmet-cli
    psmisc
    targetcli-fb
  ];
in
buildGoModule (finalAttrs: {
  pname = "linstor-gateway";
  inherit version;

  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "linstor-gateway";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+JzxW+YYzODVzuVjZbm5ZJlaIlS0Aj4KIohM+I9A1pc=";
  };

  vendorHash = "sha256-0nP7I9AZk5+KoFv2hdaOsk6fMxJz/UGGEqYBqUZy1tc=";

  nativeBuildInputs = [
    makeWrapper
  ];

  patchPhase = ''
    runHook prePatch

    substituteInPlace pkg/healthcheck/healthcheck.go \
      --replace-fail "/usr/lib/ocf" "${ocf-resource-agents}/usr/lib/ocf"

    runHook postPatch
  '';

  buildPhase = ''
    runHook preBuild

    go build -o linstor-gateway

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    ls
    mkdir -p $out/bin
    install -D -m 0750 ./linstor-gateway $out/bin/

    runHook postInstall
  '';
  postInstall = ''
    wrapProgram $out/bin/linstor-gateway \
      --prefix PATH : "${makeBinPath utils}"

  '';

  meta = with lib; {
    description = "Manages Highly-Available iSCSI targets, NVMe-oF targets, and NFS exports via LINSTOR";
    homepage = "https://github.com/LINBIT/linstor-gateway";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
})
