{
  stdenv,
  lib,
  fetchurl,
  nukeReferences,
  gitMinimal,
  coccinelle,
  linuxPackages,
  kernel ? linuxPackages.kernel,
}:

stdenv.mkDerivation {
  pname = "drbd9-dkms";
  version = "9.1.23";
  src = fetchurl {
    url = "https://pkg.linbit.com//downloads/drbd/9/drbd-9.1.23.tar.gz";
    sha256 = "sha256-Jyc8ltaNY5m9wPmiFYHE6+Z/s4cgblX4cn0FWVuvHK4=";
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

  meta = with lib; {
    description = "A kernel module of drbd9";
    homepage = "https://github.com/LINBIT/drbd";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
