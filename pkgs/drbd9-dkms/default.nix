{
  stdenv,
  lib,
  fetchFromGitHub,
  nukeReferences,
  gitMinimal,
  coccinelle,
  linuxPackages,
  kernel ? linuxPackages.kernel,
}:
let
  version = "9.3.1";
in
stdenv.mkDerivation {
  pname = "drbd9-dkms";
  inherit version;
  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "drbd";
    rev = "drbd-${version}";
    fetchSubmodules = true;
    leaveDotGit = true;
    sha256 = "sha256-VWQA+sfppeXhWLYoT/2D+CSS4KQ1LYmtycyJb86tVlQ=";
  };

  hardeningDisable = [
    "pic"
    "format"
  ];
  nativeBuildInputs = [
    nukeReferences
    gitMinimal
    coccinelle
  ]
  ++ kernel.moduleBuildDependencies;

  kernel = kernel.dev;
  kernelVersion = kernel.modDirVersion;

  makeFlags = [
    "KVER=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "ARCH=x86"
    "DESTDIR=$(out)"
  ];

  installPhase = ''
    mkdir -p $out/lib/modules/$kernelVersion/updates
      for x in $(find . -name '*.ko'); do
        nuke-refs $x
        cp $x $out/lib/modules/$kernelVersion/updates/
      done
  '';

  passthru.updateOptions = [
    "--version-regex"
    "'drbd-(.*)'"
  ];
  meta = with lib; {
    description = "A kernel module of drbd9";
    homepage = "https://github.com/LINBIT/drbd";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
