{ config, lib, pkgs, supportedSystems, ... }:
let
  zshCacheDir = "${config.xdg.cacheHome}/zsh";
  fzfCache = "${zshCacheDir}/fzf-integration.zsh";
  fastSyntaxHighlighting = pkgs.zsh-fast-syntax-highlighting;
  zshAsync = pkgs.fetchFromGitHub {
    owner = "marlonrichert";
    repo = "z-async";
    rev = "5370537de80670b4a97e49cd253d15067709c0a6";
    hash = "sha256-tPosFoZSaUShaRpv7ca9BdOMREfmhnzjd/VKHSshhXo=";
  };
  zshAutocomplete = pkgs.zsh-autocomplete.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      install -Dm644 ${zshAsync}/z-async \
        "$out/share/zsh-autocomplete/z-async/z-async"
    '';
  });

  initDir = ./shell/init;
  readZsh = file: builtins.readFile (initDir + "/${file}");

  # Path variables injected before the init scripts so the sourced .zsh files
  # stay free of Nix interpolation. 02-main.zsh unsets them after use.
  initPreamble = ''
    # Paths resolved at build time from Nix; referenced by init scripts.
    _dotfiles_fzf_cache="${fzfCache}"
    _dotfiles_fsh_plugin="${fastSyntaxHighlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
    # flake.nix supportedSystems, used by the `dotfiles` completion.
    _dotfiles_hosts=(${lib.concatStringsSep " " supportedSystems})
  '';
in
{
  programs.zsh = {
    enable = true;
    # zsh-autocomplete runs compinit itself; Home Manager's compinit runs too
    # early for the plugin's setup model.
    enableCompletion = false;

    shellAliases = {
      "ll" = "ls --color=tty -lh";
      "l" = "ls --color=tty -lah";
      "la" = "ls --color=tty -lAh";
      "ls" = "ls --color=tty";
      "diff" = "diff --color";
    };

    plugins = [
      {
        name = "zsh-autocomplete";
        src = zshAutocomplete;
        file = "share/zsh-autocomplete/zsh-autocomplete.plugin.zsh";
      }
    ];

    # Ordering against Home Manager's own content (plugins < 910, shellInit
    # 1000): 01-setup before plugins, 02-main after them, mise and 03-tail after
    # shellInit.
    initContent = lib.mkMerge [
      (lib.mkOrder 500 initPreamble)
      (lib.mkOrder 550 (readZsh "01-setup.zsh"))
      (lib.mkOrder 910 (readZsh "02-main.zsh"))
      (lib.mkOrder 1090 ''
        eval "$(${pkgs.mise}/bin/mise activate zsh)"
      '')
      (lib.mkOrder 1100 (readZsh "03-tail.zsh"))
    ];
    # Use shims in .zshenv so SSH and other non-interactive zsh processes can
    # resolve environment-owned mise tools without relying on prompt hooks.
    envExtra = ''
      export PATH="${config.home.homeDirectory}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
      eval "$(${pkgs.mise}/bin/mise activate zsh --shims)"
    '';
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
  };

  # z: smart directory jumping
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = [
    pkgs.pure-prompt
  ];

  # Regenerate fzf key-binding cache and invalidate compdump on activation.
  home.activation.zshPerformanceCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
    if command -v ${pkgs.fzf}/bin/fzf >/dev/null 2>&1; then
      ${pkgs.fzf}/bin/fzf --zsh > "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/fzf-integration.zsh"
    fi
    rm -f "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-"*
  '';
}
