# Compatibility shim. A CLI installed before this change still lists this path
# in upgrade_paths, so `dotfiles upgrade` would fail when the pull deletes the
# file. Keep it until every machine runs the new CLI, then delete it.
{
  cli = "0.2.0-rc.2";
  tui = "0.16.1";
  node = "24.18.0";
}
