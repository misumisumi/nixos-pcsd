{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "linstor-gui";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "linstor-gui";
    tag = "v${version}";
    hash = "sha256-RFX2z/ST9L0oXe8oOdG5mYb6C6DuEFegOpy7hYym3WA=";
  };

  npmDepsHash = "sha256-i7/XW/q5vssjs95IEHZpjSGB2H56ngtVeFYga0UTs78=";

  buildPhase = ''
    runHook preBuild
    npmBuildHook
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r dist $out/ui
    cp -r node_modules $out

    runHook postInstall
  '';

  meta = with lib; {
    description = "Web-Based GUI frontend for LINSTOR Resources ";
    homepage = "https://github.com/LINBIT/linstor-gui";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
