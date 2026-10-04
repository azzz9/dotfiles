{ ... }:

{
  imports = [
    ../../modules/common.nix
    ../../modules/headless.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "headless";
}
