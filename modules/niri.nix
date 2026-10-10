{ config, repoDir, ... }:
{
  # niri reads both files and never writes them, so the out-of-store links keep
  # edits in this checkout live. The config names the imecaps layout, so the two
  # travel together.
  home.file.".config/niri/config.kdl" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/modules/niri/config.kdl";
    force = true;
  };
  home.file.".config/xkb/symbols/imecaps" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/modules/niri/imecaps";
    force = true;
  };
}
