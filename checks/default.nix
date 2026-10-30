# The verification layer. scripts/check.sh, the pre-push hook, and CI all run
# these, so a check cannot drift between them.
{ self, pkgs, platformMachines }:
let
  skillsSource = self.inputs.skills;
  parseGeneratedConfigs = host:
    let
      activationPackage = self.homeConfigurations.${host}.activationPackage;
    in
    ''
      files=${activationPackage}/home-files
      for f in .config/herdr/config.toml; do
        python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$files/$f"
      done
      for f in .config/lazygit/config.yml .config/gh/config.yml; do
        yq -e '.' "$files/$f" > /dev/null
      done
      zsh -n "$files/.zshrc"
      lua -e "assert(loadfile('$files/.config/nvim/init.lua'))"
      require_link() {
        local file="$1" expected="$2" target
        if [ ! -L "$files/$file" ]; then
          echo "generated-configs: ${host} $file is not a symlink" >&2
          exit 1
        fi
        target=$(readlink -e "$files/$file" || true)
        if [ "$target" != "$expected" ]; then
          echo "generated-configs: ${host} $file resolves to '$target', not '$expected'" >&2
          exit 1
        fi
      }
      require_link .pi/agent/AGENTS.md "${skillsSource}/AGENTS.md"
      require_link .pi/agent/APPEND_SYSTEM.md "${skillsSource}/APPEND_SYSTEM.md"
      # The hermes unit gets a PATH of store paths, so a command the agent
      # shells out to is absent unless modules/hermes.nix lists it. systemd-run
      # scopes each cron worker into its own transient unit, and without it on
      # PATH every worker drops to an unscoped subprocess with no message. Only
      # Linux has the unit, and pkgs.systemd does not evaluate on darwin, so the
      # check stays behind the stdenv test.
      ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        hermes_unit="$files/.config/systemd/user/hermes-agent.service"
        if [ -e "$hermes_unit" ]; then
          grep -q '${pkgs.systemd}/bin' "$hermes_unit" || {
            echo "generated-configs: $host hermes-agent.service has no systemd-run on PATH" >&2
            exit 1
          }
        fi
      ''}
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
  # A live link that follows the environment points at whatever checkout ran the
  # switch, and deleting that checkout leaves the target unreadable. The path is
  # a machine fact, so it comes from the machines row.
  link-path = pkgs.runCommand "link-path" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
    for path in flake.nix hosts modules dotfiles-cli.nix; do
      test -e "${self}/$path"
    done
    if grep -rn 'getEnv "DOTFILES' ${self}/flake.nix ${self}/hosts ${self}/modules ${self}/dotfiles-cli.nix; then
      echo "a link path reads DOTFILES_* from the environment; name it in the machines row instead" >&2
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
  # modules/pin-names.txt and flake.nix's packages must name the same set: a pin
  # in one and not the other is never bumped or never builds. `dotfiles` is the
  # CLI and codediff-watcher has its own per-platform step in bump-pins.sh, so
  # neither is listed here.
  pin-names = pkgs.runCommand "pin-names" {
    nativeBuildInputs = [ pkgs.gawk ];
  } ''
    awk -v packages="${pkgs.lib.concatStringsSep " " (builtins.attrNames self.packages.${pkgs.stdenv.hostPlatform.system})}" -v exempt="dotfiles codediff-watcher" '
      BEGIN {
        count = split(packages, name, " ")
        for (i = 1; i <= count; i++) is_package[name[i]] = 1
        count = split(exempt, name, " ")
        for (i = 1; i <= count; i++) is_exempt[name[i]] = 1
      }
      /^[[:space:]]*(#|$)/ { next }
      {
        line = $0
        sub(/[[:space:]]+$/, "", line)
        listed[line] = 1
      }
      END {
        bad = 0
        for (line in listed) {
          if (!(line in is_package)) {
            printf "pin-names: %s is listed but flake.nix exposes no such package\n", line > "/dev/stderr"
            bad = 1
          }
        }
        for (line in is_package) {
          if (!(line in listed) && !(line in is_exempt)) {
            printf "pin-names: %s is a flake package but modules/pin-names.txt does not list it, so bump-pins.sh never bumps it\n", line > "/dev/stderr"
            bad = 1
          }
        }
        exit bad
      }
    ' "${self}/modules/pin-names.txt"
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
  # The pi tarball bump rewrites modules/pi.nix by hand, so its parse and
  # rewrite are checked here rather than only when a release moves.
  pi-tarballs = pkgs.runCommand "pi-tarballs" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    python3 ${self}/scripts/bump-pi-tarballs.py --selftest
    touch $out
  '';
  # The patch and the tarball pin live in modules/pi.nix, so a version bump
  # moves both.
  teleport-slot = pkgs.runCommand "teleport-slot" {
    nativeBuildInputs = [ pkgs.nodejs pkgs.patch pkgs.gnutar pkgs.gzip ];
  } ''
    mkdir src
    tar -xzf ${pkgs.fetchurl {
      url = "https://registry.npmjs.org/pi-agent-teleport/-/pi-agent-teleport-0.2.8.tgz";
      hash = "sha256-EluPW4hkiR7rUDApVTSJMooQHfEzh7cNAU4wTiyqd7s=";
    }} -C src --strip-components=1
    cd src
    patch -p1 < ${self}/modules/pi/teleport-agent-tab.patch
    cp ${self}/checks/teleport-slot.mjs .
    node --experimental-strip-types teleport-slot.mjs
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
