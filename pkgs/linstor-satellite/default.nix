{
  lib,
  stdenv,
  gradle,
  protobuf_31,
  openjdk,
  makeWrapper,
  fetchFromGitHub,
  python3,
  runtimeShell,
  bcache-tools,
  coreutils,
  cryptsetup,
  drbd,
  kmod,
  lsscsi,
  lvm2,
  nvme-cli,
  socat,
  spdk,
  systemd,
  thin-provisioning-tools,
  thin-send-recv,
  util-linux,
  zfs,
  zstd,
}:
let
  version = "1.33.1";
  pname = "linstor-satellite";

  inherit (lib) makeBinPath removePrefix;
  utils = [
    bcache-tools
    coreutils
    cryptsetup
    drbd
    kmod
    lsscsi
    lvm2
    nvme-cli
    openjdk
    socat
    spdk
    systemd
    thin-provisioning-tools
    thin-send-recv
    util-linux
    zfs
    zstd
  ];
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "linstor-server";
    tag = "v${finalAttrs.version}";
    fetchSubmodules = true;
    leaveDotGit = true;
    hash = "sha256-w0E0aVENW2ZFBdgqz0TuLWi/LhP3hBtcHNjXtDIIKTE=";
  };

  nativeBuildInputs = [
    gradle
    makeWrapper
    protobuf_31
    python3
  ];
  buildInputs = [
    openjdk
  ];
  postPatch =
    let
      inherit (builtins) concatStringsSep;
    in
    ''
      substituteInPlace ./build.gradle \
      --replace-fail '(${
        concatStringsSep " + " [
          "\"$\{projectDir\}/tools/protoc-\""
          "protobufVersion"
          "\'\\'\/bin/protoc\\''"
        ]
      })' "('${protobuf_31}/bin/protoc')"

      substituteInPlace ./satellite/src/main/java/com/linbit/linstor/layer/storage/spdk/utils/SpdkLocalCommands.java \
        --replace-fail "rpc.py" "spdk-rpc"
    '';
  gradleFlags = [
    "-PversionOverride=${finalAttrs.version}"
    "-Dorg.gradle.java.home=${openjdk}"
  ];

  # if the package has dependencies, mitmCache must be set
  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };

  # this is required for using mitm-cache on Darwin
  __darwinAllowLocalNetworking = true;

  preBuild = ''
    mkdir -p server/generated-resources
    cat <<EOF > server/generated-resources/version-info.properties
    version=${finalAttrs.version}
    git.commit.id=$(head .git/info/refs | cut -d$'\t' -f1)
    build.time=1970-01-01T00:00:00+00:00
    EOF
  '';

  installPhase =
    let
      target = removePrefix "linstor-" pname;
    in
    ''
      runHook preInstall

      mkdir -p $out/{bin,lib}
      cd ${target}/build/distributions
      tar -xvf ${target}-${version}.tar
      cd ${target}-${version}
      cp -r bin/* $out/bin/
      cp -r lib/* $out/lib

      runHook postInstall
    '';

  postInstall = ''
    while read -r file; do
      substituteInPlace "$file" \
        --replace-warn "#!/bin/sh" "#!${runtimeShell}"
      wrapProgram "$file" \
        --set JAVA_HOME ${openjdk} \
        --prefix PATH : ${makeBinPath utils}
    done < <(find $out/bin -type f)
  '';
  passthru.updateOptions = [
    "--override-filename"
    "pkgs/linstor-server/default.nix"
  ];
  meta = with lib; {
    description = "High Performance Software-Defined Block Storage for container, cloud and virtualisation. Fully integrated with Docker, Kubernetes, Openstack, Proxmox etc.";
    homepage = "https://github.com/LINBIT/linstor-server";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
})
