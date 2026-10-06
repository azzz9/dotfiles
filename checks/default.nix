# The verification layer. scripts/check.sh, the pre-push hook, and CI all run
# these, so a check cannot drift between them. Registry-vs-disk equality is
# enforced by asserts in modules/nvim.nix and hosts/default.nix.
{ self, pkgs, platformMachines }:
let
  parseGeneratedConfigs = host:
    let
      activationConfig = self.homeConfigurations.${host}.config.home.activation;
      activationNames = builtins.attrNames activationConfig;
      herdrAutoTitleAfter = activationConfig.herdrAutoTitle.after;
      activationPackage = self.homeConfigurations.${host}.activationPackage;
    in
    assert builtins.all
      (name: name == "herdrAutoTitle" || builtins.elem name herdrAutoTitleAfter)
      activationNames;
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
      # Every package row is a store path or an exact npm spec. A row that
      # regressed to a `git:` spec would leave pi fetching on its own again.
      # The managed settings file is a build input of the merge script rather
      # than a home file, so read it through the activation script.
      merge=$(grep -oh '/nix/store/[^ ]*-pi-settings-managed' ${activationPackage}/activate | head -n 1)
      settings=$(grep -oh '/nix/store/[^ ]*-pi-managed-settings.json' "$merge" | head -n 1)
      jq -e '[.packages[] | if type == "object" then .source else . end] as $rows
             | ($rows | all(startswith("npm:") or startswith("/nix/store/")))
               and ([$rows[] | select(startswith("/nix/store/"))] | length > 0)' \
        "$settings" >/dev/null
      titlePin="$files/.local/share/dotfiles/herdr-auto-title-pin"
      grep -Eq '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+ [0-9a-f]{40}$' "$titlePin"
      test "$(wc -l < "$titlePin")" -eq 1
      grep -q 'dotfiles.lockdir' ${activationPackage}/activate
      grep -q 'herdr-auto-title-reconcile' ${activationPackage}/activate
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
  actionlint = pkgs.runCommand "actionlint" { nativeBuildInputs = [ pkgs.actionlint ]; } ''
    actionlint ${self}/.github/workflows/*.yml
    touch $out
  '';
  # The generated files are only text until a tool parses them, so parse
  # every config this flake emits, for every machine this system builds.
  generated-configs = pkgs.runCommand "generated-configs" {
    nativeBuildInputs = [ pkgs.python3 pkgs.yq-go pkgs.zsh pkgs.lua5_1 pkgs.jq pkgs.gnugrep ];
  } (
    builtins.concatStringsSep "" (map parseGeneratedConfigs (builtins.attrNames platformMachines))
    + "touch $out"
  );
  pi-reconcile = pkgs.runCommand "pi-reconcile" {
    nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.jq ];
  } ''
    export HOME=$TMPDIR/home
    export PATH=$TMPDIR/bin:$PATH
    mkdir -p "$HOME/.pi/agent/npm/node_modules" "$TMPDIR/bin"

    # Keep the heredoc body at this indentation; nix strips the common
    # indent from the whole string, which is what puts the shebang at
    # column zero in the stub.
    cat > "$TMPDIR/bin/pi" <<'STUB'
    #!/bin/sh
    printf '%s\n' "$*" >> "$HOME/pi-calls"
    STUB
    chmod +x "$TMPDIR/bin/pi"

    npmName='@example/rpiv-todo'
    npmSource="npm:$npmName@2.12.0"
    settings=$HOME/.pi/agent/settings.json
    source ${self}/scripts/pi-reconcile.sh

    npm_dir=$HOME/.pi/agent/npm/node_modules/$npmName
    mkdir -p "$npm_dir"
    printf '{"version":"2.12.0"}\n' > "$npm_dir/package.json"
    printf '{"packages":["%s"]}\n' "$npmSource" > "$settings"

    # On the pinned version, the next apply asks pi nothing.
    pi_reconcile
    test ! -e "$HOME/pi-calls"

    # An npm package whose installed version differs is installed once.
    printf '{"version":"2.11.0"}\n' > "$npm_dir/package.json"
    pi_reconcile
    test "$(cat "$HOME/pi-calls")" = "install $npmSource"

    # On the pinned version, the next apply asks pi nothing.
    printf '{"version":"2.12.0"}\n' > "$npm_dir/package.json"
    pi_reconcile
    test "$(wc -l < "$HOME/pi-calls")" = 1

    # A package.json that is not there needs the install too.
    rm -rf "$npm_dir"
    pi_reconcile
    test "$(wc -l < "$HOME/pi-calls")" = 2

    # An unpinned source names no version, so there is nothing to compare.
    printf '{"packages":["npm:example-unpinned"]}\n' > "$settings"
    pi_reconcile
    test "$(wc -l < "$HOME/pi-calls")" = 2

    # No settings file, nothing to converge, and the apply still succeeds.
    rm -f "$settings"
    pi_reconcile
    test "$(wc -l < "$HOME/pi-calls")" = 2

    # A pi that cannot install the package fails the apply.
    printf '{"packages":["%s"]}\n' "$npmSource" > "$settings"
    mkdir -p "$npm_dir"
    printf '{"version":"2.11.0"}\n' > "$npm_dir/package.json"
    printf '#!/bin/sh\nexit 1\n' > "$TMPDIR/bin/pi"
    chmod +x "$TMPDIR/bin/pi"
    if pi_reconcile 2>/dev/null; then
      echo "pi_reconcile passed while pi failed" >&2
      exit 1
    fi
    touch $out
  '';
}
