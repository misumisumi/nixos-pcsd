{
  lib,
  fetchFromGitHub,
  python3Packages,
}:
let
  inherit (python3Packages) buildPythonApplication;
in
buildPythonApplication rec {
  pname = "linstor-client";
  version = "1.27.1";

  src = fetchFromGitHub {
    owner = "LINBIT";
    repo = "linstor-client";
    tag = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-k/b/5fwwP+3wsnlFvDmACdmEokFTQjoTLjzO8zojhp8=";
  };
  postPatch = ''
    substituteInPlace \
      "setup.py" \
      --replace-fail  "\"python3-setuptools\"" ""
  '';

  pyproject = true;
  build-system = with python3Packages; [ setuptools ];
  propagatedBuildInputs = with python3Packages; [
    linstor-api-py
    distutils
  ];

  meta = with lib; {
    description = "Python client for LINSTOR";
    homepage = "https://github.com/LINBIT/linstor-client";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
