{
  fetchFromGitHub,
  python3Packages,
}:
let
  inherit (python3Packages) buildPythonPackage;
in
buildPythonPackage rec {
  pname = "linstor-api-py";
  version = "1.26.1";
  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "linstor-api-py";
    tag = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-AQMK838P+l0BKaCSOO/+FxNVN3PZsC05n5zgut86RZs=";
  };

  pyproject = true;
  build-system = with python3Packages; [
    setuptools
  ];
}
