{
  lib,
  fetchFromGitHub,
  python3Packages,
}:
let
  inherit (python3Packages) buildPythonPackage;
  version = "1.27.1";
in
buildPythonPackage {
  pname = "linstor-api-py";
  inherit version;
  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "linstor-api-py";
    tag = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-5DKwrylidnIA5OUVIPHkXAQoS/XM4YMN65WDBI3SJME=";
  };

  pyproject = true;
  build-system = with python3Packages; [
    setuptools
  ];

  meta = with lib; {
    description = "LINSTOR Python API";
    homepage = "https://github.com/LINBIT/linstor-api-py";
    license = licenses.lgpl3Plus;
    platforms = platforms.linux;
  };
}
