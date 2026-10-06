{ pkgs, ... }:
{
  # TUIOS is on trial: the binary only. herdr stays the default multiplexer
  # (modules/herdr.nix, HERDR_AUTO_START) until TUIOS earns the migration, so
  # this module holds no config.toml and no pi state integration yet. Add those
  # per finding, and delete this module if the trial fails.
  home.packages = [ pkgs.tuios ];
}
