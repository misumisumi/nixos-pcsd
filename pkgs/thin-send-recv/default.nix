{
  lib,
  stdenv,
  fetchFromGitHub,
  flex,
}:
let
  version = "1.1.3";
in
stdenv.mkDerivation {
  pname = "thin-send-recv";
  inherit version;
  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "thin-send-recv";
    tag = "v${version}";
    hash = "sha256-2WDVXnd2Y5l+kQwXBHbHDBhvqefwj2uewAmaI1HIVa0=";
  };

  nativeBuildInputs = [ flex ];

  installPhase = ''
    mkdir -p $out/bin
    install -D thin_send_recv $out/bin/.thin_send_recv
    ln -f -s $out/bin/.thin_send_recv $out/bin/thin_send
    ln -f -s $out/bin/.thin_send_recv $out/bin/thin_recv
  '';

  meta = with lib; {
    description = "zfs send and zfs recv alike for the LVM thin world";
    homepage = "https://github.com/LINBIT/thin-send-recv";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
