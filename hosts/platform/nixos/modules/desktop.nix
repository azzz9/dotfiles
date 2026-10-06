# The desktop stack, portable across machines. Hardware that only fits one
# machine lives in hosts/platform/nixos/machines/<name>/ next to its
# hardware-configuration.nix. Every scalar is a default, so this machine's own
# configuration.nix can set it; lists and attrsets merge already.
{ lib, pkgs, ... }:

{
  i18n.inputMethod = {
    enable = lib.mkDefault true;
    type = lib.mkDefault "fcitx5";
    fcitx5.addons = [ pkgs.fcitx5-mozc ];
    fcitx5.waylandFrontend = lib.mkDefault true;
  };

  services.xserver.enable = lib.mkDefault true;

  services.displayManager.sddm.enable = lib.mkDefault true;
  services.desktopManager.plasma6.enable = lib.mkDefault true;
  programs.niri.enable = lib.mkDefault true;
  # Not a default: NixOS picks this one itself with mkDefault from the enabled
  # manager, and two defaults with different values conflict.
  services.displayManager.defaultSession = "niri";

  services.xserver.xkb = {
    layout = lib.mkDefault "us";
    variant = lib.mkDefault "";
  };

  services.printing.enable = lib.mkDefault true;

  services.pulseaudio.enable = lib.mkDefault false;
  security.rtkit.enable = lib.mkDefault true;
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };

  users.users."azzz".packages = with pkgs; [
    kdePackages.kate
  ];

  programs.firefox.enable = lib.mkDefault true;

  programs.steam.enable = lib.mkDefault true;
  environment.systemPackages = with pkgs; [
    ghostty
    discord
    noctalia
    xwayland-satellite
    haruna
    mpv
  ];

  # kbuildsycoca6 looks for <XDG_MENU_PREFIX>applications.menu and builds a
  # service database with no applications when it finds none. A niri session
  # sets no XDG_MENU_PREFIX, so KDE apps would have no MIME associations at all.
  environment.etc."xdg/menus/applications.menu".source =
    lib.mkDefault "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
}
