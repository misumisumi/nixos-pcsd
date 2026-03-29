final: prev: {
  fence-agents = final.callPackage ./fence-agents { };

  drbd-reactor = final.callPackage ./drbd-reactor { };
  drbd9-dkms = final.callPackage ./drbd9-dkms { };
  linstor-client = final.callPackage ./linstor-client { };
  linstor-controller = final.callPackage ./linstor-controller { };
  linstor-gateway = final.callPackage ./linstor-gateway { };
  linstor-gui = final.callPackage ./linstor-gui { };
  linstor-satellite = final.callPackage ./linstor-satellite { };
  thin-send-recv = final.callPackage ./thin-send-recv { };

  pcs = final.callPackage ./pcs { };
  pcs-web-ui = final.callPackage ./pcs-web-ui { };
  pacemaker = final.callPackage ./pacemaker { };
  resource-agents = final.callPackage ./resource-agents { };
  ocf-resource-agents = final.callPackage ./ocf-resource-agents { };

  python3 =
    let
      pythonPackagesOverlays = (prev.pythonPackagesOverlays or [ ]) ++ [
        (pfinal: pprev: {
          linstor-api-py = final.callPackage ./linstor-api-py { };
          pyagentx = final.callPackage ./pyagentx { };
        })
      ];
      self = prev.python3.override {
        inherit self;
        packageOverrides = prev.lib.composeManyExtensions pythonPackagesOverlays;
      };
    in
    self;
  python3Packages = final.python3.pkgs;
}
