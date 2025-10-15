{
  fetchFromGitHub,
  python3Packages,
}:
let
  inherit (python3Packages) buildPythonApplication;
in
buildPythonApplication rec {
  pname = "linstor-client";
  version = "1.26.1";

  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "linstor-client";
    tag = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-QEP3YLmBwvNvUcU/OLPgkb2O9tguOngYVj0HRhIGd0A=";
  };

  pyproject = true;
  build-system = with python3Packages; [ setuptools ];
  propagatedBuildInputs = with python3Packages; [
    linstor-api-py
    distutils
  ];
}
