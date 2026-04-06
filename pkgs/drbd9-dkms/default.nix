{
  stdenv,
  lib,
  fetchFromGitHub,
  coccinelle,
  flex,
  gitMinimal,
  python3,
  linuxPackages,
  kernel ? linuxPackages.kernel,
  kernelModuleMakeFlags ? linuxPackages.kernelModuleMakeFlags,
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
    sha256 = "sha256-IzMRPbCQ8RvXo9fVY5fCNzBsvRaUe0iNmp4Ft4YGpug=";
  };

  hardeningDisable = [
    "pic"
    "format"
  ];

  nativeBuildInputs = [
    coccinelle
    flex
    gitMinimal
    kernel.moduleBuildDependencies
    python3
  ];

  kernel = kernel.dev;
  kernelVersion = kernel.modDirVersion;

  enableParallelBuilding = true;

  makeFlags = kernelModuleMakeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "KVER=${kernel.version}"
    "INSTALL_MOD_PATH=${placeholder "out"}"
    "M=$(sourceRoot)"
    "SPAAS=false"
  ];

  installFlags = [ "INSTALL_MOD_PATH=${placeholder "out"}" ];

  postPatch = ''
    patchShebangs .
    substituteInPlace Makefile --replace 'SHELL=/bin/bash' 'SHELL=${builtins.getEnv "SHELL"}'
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
