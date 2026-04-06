{ drbd }:
drbd.overrideAttrs (old: {
  configureFlags = old.configureFlags ++ [
    "--with-initscripttype=both"
    "--with-systemdunitdir=/lib/systemd/system"
    "--with-systemdpresetdir=/lib/systemd/system-preset"
  ];
})
