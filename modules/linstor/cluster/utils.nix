{ lib }:
let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    mapAttrsToList
    optionalString
    ;
in
{
  #NOTE: linstor cause errors if you already have a node, storage pool, resource group etc, so we ignore the error and continue
  createNode =
    {
      name,
      address,
      type,
      extraArgs,
    }:
    let
      cmd =
        "linstor node create ${name}"
        + (optionalString (address != "") " ${address}")
        + " --node-type ${type} ${concatStringsSep " " extraArgs}";
    in
    ''
      ${cmd} || true
    '';

  createStoragePool =
    {
      node,
      name,
      type,
      volumeGroup,
      physicalStorage,
      extraArgs,
    }:
    let
      #NOTE: linstor create <VG>/<LV>=linstor_<volueGroup>/<volumeGroup> for lvmthin,
      # but create <VG>=<volumeGroup> for other types, so we need to handle this case
      volumeGroup' =
        if (physicalStorage.devices != [ ] && physicalStorage.provider == "lvmthin") then
          "linstor_${volumeGroup}/${volumeGroup}"
        else
          volumeGroup;
    in
    ''
      CREATE_FAILED=0
    ''
    + optionalString (physicalStorage.devices != [ ]) ''
      if ! linstor physical-storage create-device-pool --pool-name ${volumeGroup} --storage-pool ${name} ${concatStringsSep " " physicalStorage.extraArgs} ${physicalStorage.provider} ${node} ${concatStringsSep " " physicalStorage.devices}; then
        CREATE_FAILED=1
      fi
    ''
    + ''
      # When failed to "physical-storage create", it means missing physical storage or storage-pool is already created.
      # So trying to create storage-pool if physical storage is missing, and ignore the error if storage-pool is already created.
      if [ $CREATE_FAILED -eq 1 ]; then
        linstor storage-pool create ${type} ${concatStringsSep " " extraArgs} ${node} ${name} ${volumeGroup'} || true
      fi
    '';

  createResourceGroup =
    {
      name,
      pool,
      placeCount,
      extraArgs,
      extraCmds,
      resources,
      properties ? { },
      encrypt ? {
        enable = false;
      },
    }:
    let
      cmdSpawn = concatMapStringsSep "\n" (r: ''
        linstor resource-group spawn-resources ${concatStringsSep " " r.extraArgs} ${name} ${r.name} ${r.size} || true

        ${r.extraCmds r.name}
      '') resources;
    in
    ''
      linstor resource-group create ${name} --storage-pool ${pool} ${optionalString encrypt.enable "--layer-list luks,storage"} --place-count ${toString placeCount} ${concatStringsSep " " extraArgs} || true

      ${extraCmds name}

      linstor volume-group create ${name} || true

      ${concatStringsSep "\n" (
        mapAttrsToList (k: v: "linstor resource-group set-property ${name} ${k} ${v}") properties
      )}

      ${cmdSpawn}
    '';
}
