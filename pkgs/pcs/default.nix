{
  lib,
  python3Packages,
  # nix build inputs
  bundlerEnv,
  fetchFromGitHub,
  # deps
  # autoconf,
  autoreconfHook,
  automake,
  libffi,
  libpam-wrapper,
  nss,
  pacemaker,
  corosync,
  pam,
  pkg-config,
  psmisc,
  ruby,
  systemd,
  # overrides
  withWebUI ? false,
  pcs-web-ui ? null,
  ...
}:
let
  inherit (lib) getLib optionalString;

  pname = "pcs";
  version = "0.12.1";

  rubyEnv = bundlerEnv {
    name = "pcs-env-${version}";
    inherit ruby;
    gemdir = ./.;
  };
in
python3Packages.buildPythonPackage {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "ClusterLabs";
    repo = "pcs";
    rev = "v${version}";
    hash = "sha256-b5qIgW4akJrNThGBB54KnFpDyEA8xvyfFcHnYEZ0zW0=";
  };

  # Curl test assumes network access
  doCheck = false;
  pyproject = true;
  build-system = with python3Packages; [ setuptools ];

  buildInputs = [
    libpam-wrapper
    ruby
    psmisc
    corosync
    nss.tools
    systemd
    pacemaker
  ];
  propagatedBuildInputs = with python3Packages; [
    cryptography
    dateutil
    lxml
    pycurl
    pyparsing
    tornado
    dacite
    pyagentx
    libffi
  ];

  nativeBuildInputs = [
    autoreconfHook
    automake
    nss.tools
    pkg-config
    psmisc
    rubyEnv
    rubyEnv.wrappedRuby
    rubyEnv.bundler
    systemd
  ];
  propagatedNativeBuildInputs = with python3Packages; [
    pip
  ];

  postUnpack = ''
    # Fix version of untagged build
    echo 'printf %s "${version}"' > $sourceRoot/make/git-version-gen


    # Fix pam path https://github.com/NixOS/nixpkgs/blob/5a072b4a9d7ccf64df63645f3ee808dc115210ba/pkgs/development/python-modules/pamela/default.nix#L20
    substituteInPlace $sourceRoot/pcs/lib/auth/pam.py --replace-fail \
      'find_library("pam")' \
      '"${getLib pam}/lib/libpam.so"'


    # Fix systemd path
    substituteInPlace $sourceRoot/configure.ac \
      --replace-fail 'AC_SUBST([SYSTEMD_UNIT_DIR])' "SYSTEMD_UNIT_DIR=$out/lib/systemd/system
      AC_SUBST([SYSTEMD_UNIT_DIR])"


    # Fix paths to corosync and pacemaker executables
    substituteInPlace $sourceRoot/configure.ac \
      --replace-fail 'PCS_PKG_CHECK_VAR([COROEXECPREFIX], [corosync], [exec_prefix], [/usr])' "COROEXECPREFIX=${corosync}
      AC_SUBST([COROEXECPREFIX])"

    substituteInPlace $sourceRoot/configure.ac \
      --replace-fail 'PCS_PKG_CHECK_VAR([PCMKEXECPREFIX], [pacemaker], [exec_prefix], [/usr])' "PCMKEXECPREFIX=${pacemaker}
      AC_SUBST([PCMKEXECPREFIX])"

    substituteInPlace $sourceRoot/configure.ac \
      --replace-fail "\$prefix/libexec/pacemaker" "${pacemaker}/libexec/pacemaker"


    # Don't create var files
    substituteInPlace $sourceRoot/pcsd/Makefile.am --replace-fail \
      '$(MKDIR_P) -m 0700 $(DESTDIR)$(localstatedir)/log/pcsd' ""

    substituteInPlace $sourceRoot/pcsd/Makefile.am --replace-fail \
     '$(MKDIR_P) -m 0700 $(DESTDIR)$(localstatedir)/lib/pcsd' ""
  '';

  preConfigure = ''
    ./autogen.sh
  '';

  configureFlags = [
    "--with-distro=fedora"
    "--enable-use-local-cache-only"
    "--with-pcs-lib-dir=${placeholder "out"}/lib"
    "--with-default-config-dir=${placeholder "out"}/etc"
    "--localstatedir=/var"
  ];

  # buildInputs = with python3Packages; [
  #   pyagentx
  #   libffi
  # ];
  # ++ (with python3Packages; [
  #   pip
  #   setuptools
  #   setuptools_scm
  #   wheel
  # ]);

  installPhase = ''
    runHook preInstall

    make
    make install

    runHook postInstall
  '';

  postInstall = optionalString withWebUI ''
    rm -r $out/lib/pcsd/public/
    ln -s ${pcs-web-ui}/lib/pcsd/public $out/lib/pcsd/public
  '';

  passthru.updateScript = ./update.sh;
}
