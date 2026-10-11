# The verification layer. scripts/check.sh, the pre-push hook, and CI all run
# these, so a check cannot drift between them. Registry-vs-disk equality is
# enforced by asserts in modules/nvim.nix and hosts/default.nix.
{ self, pkgs, platformMachines }:
let
  parseGeneratedConfigs = host:
    let
      activationPackage = self.homeConfigurations.${host}.activationPackage;
    in
    ''
      files=${activationPackage}/home-files
      for f in .config/herdr/config.toml .config/hunk/config.toml; do
        python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$files/$f"
      done
      for f in .config/lazygit/config.yml .config/gh/config.yml; do
        yq -e '.' "$files/$f" > /dev/null
      done
      zsh -n "$files/.zshrc"
      lua -e "assert(loadfile('$files/.config/nvim/init.lua'))"
      # The CLI appends the system directories to PATH, never prepends
      # them: on macOS /usr/bin/sed is BSD sed and /bin/bash is 3.2, so a
      # prefix would shadow the runtime inputs the script needs.
      grep -q '^export PATH="\$PATH:' \
        ${activationPackage}/home-path/bin/dotfiles
    '';
in
{
  deadnix = pkgs.runCommand "deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
    deadnix --fail ${self}
    touch $out
  '';
  shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
    cd ${self}
    shellcheck -x scripts/*.sh .githooks/pre-push
    bash -n scripts/*.sh .githooks/pre-push
    touch $out
  '';
  # Device facts belong in hosts/platform/nixos/machines/<name>/ next to that
  # machine's hardware-configuration.nix, so a shared NixOS module cannot be
  # evaluated by another machine by mistake. The directory check keeps the grep
  # from passing silently after the tree moves.
  no-device-config = pkgs.runCommand "no-device-config" {
    nativeBuildInputs = [ pkgs.gnugrep ];
  } ''
    shared=${self}/hosts/platform/nixos/modules
    test -d "$shared"
    if grep -rnE 'hardware\.|/dev/disk|fileSystems|videoDrivers' "$shared"; then
      echo "device-specific config belongs in hosts/platform/nixos/machines/<name>/" >&2
      exit 1
    fi
    touch $out
  '';
  bootstrap = pkgs.runCommand "bootstrap" {
    nativeBuildInputs = [ pkgs.python3 pkgs.bash pkgs.coreutils pkgs.gnugrep ];
  } ''
    python3 ${self}/scripts/test-setup.py ${self}/scripts/setup-system.sh
    touch $out
  '';
  # Drives scripts/dotfiles.sh against fixture git repos with its nix build stubbed.
  # jq is here for the audit's reads, which the same fixture stubs.
  dotfiles-cli = pkgs.runCommand "dotfiles-cli" {
    nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.git pkgs.gnugrep pkgs.jq ];
  } ''
    bash ${self}/scripts/test-dotfiles.sh ${self}/scripts/dotfiles.sh
    touch $out
  '';
  actionlint = pkgs.runCommand "actionlint" { nativeBuildInputs = [ pkgs.actionlint ]; } ''
    actionlint ${self}/.github/workflows/*.yml
    touch $out
  '';
  # A secret committed here is public forever, and a Nix string reaches the
  # world-readable store, so one scan covers both. This reads the tree only,
  # because a flake copy carries no .git for a history scan.
  gitleaks = pkgs.runCommand "gitleaks" { nativeBuildInputs = [ pkgs.gitleaks ]; } ''
    gitleaks dir ${self} --redact --no-banner
    touch $out
  '';
  # The generated files are only text until a tool parses them, so parse
  # every config this flake emits, for every machine this system builds.
  generated-configs = pkgs.runCommand "generated-configs" {
    nativeBuildInputs = [ pkgs.python3 pkgs.yq-go pkgs.zsh pkgs.lua5_1 pkgs.gnugrep ];
  } (
    builtins.concatStringsSep "" (map parseGeneratedConfigs (builtins.attrNames platformMachines))
    + "touch $out"
  );
}
