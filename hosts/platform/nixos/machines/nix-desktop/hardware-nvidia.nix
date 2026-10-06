# The GPU in this machine, an RTX 3070 (Ampere, GA104). The open kernel module
# covers Turing and newer and this machine runs it, and the driver package
# follows the kernel this machine boots.
{ config, ... }:
{
  # The graphics stack the driver plugs into.
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
