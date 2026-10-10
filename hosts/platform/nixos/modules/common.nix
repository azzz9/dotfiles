# Every scalar here is a default, so this machine's own
# machines/<name>/configuration.nix can set it without an "option has conflicting
# values" error. Lists and attrsets merge already.
{ lib, pkgs, ... }:

{
  networking.networkmanager.enable = lib.mkDefault true;

  time.timeZone = lib.mkDefault "Asia/Tokyo";

  i18n.defaultLocale = lib.mkDefault "ja_JP.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  users.users."azzz" = {
    # Not defaults: NixOS's users-groups module sets these itself with
    # mkDefault, and two defaults with different values conflict. The bootstrap
    # deletes these three lines from a machine's copied configuration instead.
    isNormalUser = true;
    description = "azzz";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # mise installs tools as unpatched binaries, and so do plugin releases from
  # GitHub. Without this stub they exit 127 pointing at nix.dev/permalink/stub-ld.
  programs.nix-ld.enable = lib.mkDefault true;

  # zsh as the login shell. zsh-autocomplete runs compinit itself, so the
  # global compinit (which would run before the plugin loads) stays off.
  programs.zsh = {
    enable = lib.mkDefault true;
    enableGlobalCompInit = lib.mkDefault false;
  };

  nixpkgs.config.allowUnfree = lib.mkDefault true;
}
