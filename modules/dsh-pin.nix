# The CLI lives in a mutable prefix because it builds native modules, so there
# is no derivation for nix-update to read.
#
# Measured here: the require-builtin addon fails with Unsupported/no-getter on
# Node 22.23.2 and 24.21.0; 24.18.0 boots the CLI.
{
  cli = "0.2.0-rc.2";
  tui = "0.16.1";
  node = "24.18.0";
}
