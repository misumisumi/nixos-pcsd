{
  python3Packages,
  fetchFromGitHub,
}:
let
  inherit (python3Packages) buildPythonPackage;
in
buildPythonPackage {
  pname = "pyagentx";
  version = "0.4.pcs.2";

  pyproject = true;
  build-system = with python3Packages; [ setuptools ];

  src = fetchFromGitHub {
    owner = "ondrejmular";
    repo = "pyagentx";
    rev = "8fcc2f056b54b92c67a264671198fd197d5a1799";
    hash = "sha256-uXFRtQskF2HhHi3KhJwajPvt8c8unrBBOqxGimV74Rc=";
  };
}
