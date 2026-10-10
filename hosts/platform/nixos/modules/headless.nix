# Headless machines get sshd so they can be administered without a display, and
# keys are the only way in. nixpkgs defaults PasswordAuthentication to true, and
# on an always-on machine that is a guessable login. KbdInteractiveAuthentication
# hands the same account password to PAM, so both go off together. A machine with
# no authorized key on it yet has to drop the assertion below on purpose.
{ lib, config, ... }:

{
  services.openssh.enable = lib.mkDefault true;
  services.openssh.settings = {
    PasswordAuthentication = lib.mkDefault false;
    KbdInteractiveAuthentication = lib.mkDefault false;
  };

  assertions = [
    {
      assertion =
        config.services.openssh.settings.PasswordAuthentication == false
        && config.services.openssh.settings.KbdInteractiveAuthentication == false;
      message = ''
        A machine with sshd enabled accepts password authentication.
        Install an authorized key first, then remove the override that turned
        it back on. See hosts/platform/nixos/modules/headless.nix.
      '';
    }
  ];
}
