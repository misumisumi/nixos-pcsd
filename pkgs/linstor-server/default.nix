{
  lib,
  stdenv,
  gradle,
  protobuf_31,
  openjdk11,
  makeWrapper,
  fetchFromGitHub,
  python3,
  runtimeShell,
}:
let
  version = "1.32.3";

  common =
    pname:
    stdenv.mkDerivation (finalAttrs: {
      inherit pname version;

      src = fetchFromGitHub {
        owner = "LINBIT";
        repo = "linstor-server";
        tag = "v${finalAttrs.version}";
        fetchSubmodules = true;
        leaveDotGit = true;
        hash = "sha256-R3ScK9yvKid3RTr7NInrSIMAB26v3o62ZRRJKKb7K98=";
      };

      nativeBuildInputs = [
        gradle
        makeWrapper
        protobuf_31
        python3
      ];
      buildInputs = [
        openjdk11
      ];
      postPatch =
        let
          inherit (builtins) concatStringsSep;
        in
        ''
          substituteInPlace ./build.gradle \
          --replace-fail '(${
            concatStringsSep " + " [
              "\"$\{projectDir\}/tools/protoc-\""
              "protobufVersion"
              "\'\\'\/bin/protoc\\''"
            ]
          })' "('${protobuf_31}/bin/protoc')"
        '';
      gradleFlags = [
        "-PversionOverride=${finalAttrs.version}"
        "-Dorg.gradle.java.home=${openjdk11}"
      ];

      # if the package has dependencies, mitmCache must be set
      mitmCache = gradle.fetchDeps {
        pkg = finalAttrs.finalPackage;
        data = ./deps.json;
      };

      # this is required for using mitm-cache on Darwin
      __darwinAllowLocalNetworking = true;

      preBuild = ''
        mkdir -p server/generated-resources
        cat <<EOF > server/generated-resources/version-info.properties
        version=${finalAttrs.version}
        git.commit.id=$(head .git/info/refs | cut -d$'\t' -f1)
        build.time=1970-01-01T00:00:00+00:00
        EOF
      '';

      installPhase =
        let
          inherit (lib) removePrefix;
          target = removePrefix "linstor-" pname;
        in
        ''
          runHook preInstall

          mkdir -p $out/{bin,lib}
          cd ${target}/build/distributions
          tar -xvf ${target}-${version}.tar
          cd ${target}-${version}
          cp -r bin/* $out/bin/
          cp -r lib/* $out/lib

          runHook postInstall
        '';

      postInstall = ''
        while read -r file; do
          substituteInPlace "$file" \
            --replace-warn "#!/bin/sh" "#!${runtimeShell}"
          wrapProgram "$file" \
            --set JAVA_HOME ${openjdk11}
        done < <(find $out/bin -type f)
      '';
    });
in
lib.recurseIntoAttrs {
  linstor-controller = common "linstor-controller";
  linstor-satellite = common "linstor-satellite";
}
