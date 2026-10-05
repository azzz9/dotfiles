# The desktop stack, portable across machines. Hardware that only fits one
# machine lives in hosts/platform/nixos/machines/<name>/ next to its
# hardware-configuration.nix.
{ pkgs, ... }:

{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = [ pkgs.fcitx5-mozc ];
    fcitx5.waylandFrontend = true;
  };

  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  programs.niri.enable = true;
  services.displayManager.defaultSession = "niri";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users."azzz".packages = with pkgs; [
    kdePackages.kate
  ];

  programs.firefox.enable = true;

  programs.steam.enable = true;
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
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
}
