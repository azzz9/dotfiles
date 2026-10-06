{ config, lib, pkgs, repoDir, herdrAutoTitleSource, ... }:
let
  toastDelivery = "system";
  autoTitleReconcile = pkgs.writeShellApplication {
    name = "herdr-auto-title-reconcile";
    runtimeInputs = with pkgs; [ coreutils git go herdr jq ];
    text =
      builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ]
        (builtins.readFile ../scripts/herdr-auto-title-reconcile.sh)
      + "\nherdr_auto_title_reconcile\n";
  };
  herdrAutoTitleAfter = builtins.filter
    (name: name != "herdrAutoTitle")
    (builtins.attrNames config.home.activation);
in
{
  # herdr agent multiplexer, https://github.com/ogulcancelik/herdr
  home.packages = [ pkgs.herdr ];

  # Herdr owns the checkout and registry.
  home.file.".local/share/dotfiles/herdr-auto-title-pin".text =
    "${herdrAutoTitleSource.owner}/${herdrAutoTitleSource.repo} ${herdrAutoTitleSource.rev}\n";

  home.activation.herdrAutoTitle = lib.hm.dag.entryAfter herdrAutoTitleAfter ''
    lock_dir="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/dotfiles.lockdir"
    if [ "''${DOTFILES_DIR:-}" = ${lib.escapeShellArg repoDir} ] && [ -d "$lock_dir" ]; then
      run ${autoTitleReconcile}/bin/herdr-auto-title-reconcile
    fi
  '';

  xdg.configFile."herdr/config.toml".text = ''
    # Managed by Home Manager (modules/herdr.nix); do not edit directly.

    onboarding = false

    [theme]
    name = "kanagawa"

    [theme.custom]
    # Terminal default background, so Ghostty's background-opacity reaches the tab bar
    panel_bg = "reset"

    [terminal]
    # New panes/tabs/workspaces inherit the source pane's CWD
    new_cwd = "follow"

    [keys]
    # / = side-by-side, - = stacked
    split_vertical = "prefix+/"
    split_horizontal = "prefix+-"

    # Overrides the default prefix+p / prefix+n; prefix+1..9 jumps directly.
    previous_tab = "alt+shift+h"
    next_tab = "alt+shift+l"

    previous_workspace = "alt+shift+k"
    next_workspace = "alt+shift+j"

    # Worktrees come from `git wt` (modules/git.nix: wt.basedir = "../{gitroot}-wt"),
    # so this only opens existing checkouts as grouped child spaces; new_worktree stays unused.
    open_worktree = "prefix+shift+o"

    # Direct (no-prefix) pane navigation. type = "shell" runs detached;
    # `herdr pane focus` talks to the server socket.
    [[keys.command]]
    key = "alt+h"
    type = "shell"
    command = "herdr pane focus --direction left"

    [[keys.command]]
    key = "alt+j"
    type = "shell"
    command = "herdr pane focus --direction down"

    [[keys.command]]
    key = "alt+k"
    type = "shell"
    command = "herdr pane focus --direction up"

    [[keys.command]]
    key = "alt+l"
    type = "shell"
    command = "herdr pane focus --direction right"

    # Session-modal scratchpad over ~/memo.md. Exiting nvim closes the popup.
    [[keys.command]]
    key = "prefix+m"
    type = "popup"
    command = "nvim ~/memo.md"
    description = "edit ~/memo.md"
    width = "80%"
    height = "80%"

    # lazygit in a full-tab overlay pane; exiting lazygit closes the pane.
    # prefix+g is the session navigator and prefix+shift+g is new_worktree,
    # both in use, so this uses the alt+shift+ letter row that already carries
    # tab and workspace navigation.
    [[keys.command]]
    key = "alt+shift+g"
    type = "pane"
    command = "lazygit"
    description = "lazygit"

    [[keys.command]]
    key = "prefix+e"
    type = "plugin_action"
    command = "chmarax.herdr-nvim.toggle"
    description = "nvim sidebar"

    [[keys.command]]
    key = "prefix+o"
    type = "plugin_action"
    command = "chmarax.herdr-nvim.pick-file"
    description = "open file from agent output"

    [session]
    # Resume AI-agent panes into their native sessions after a server restart
    resume_agents_on_restore = true

    [ui]
    show_agent_labels_on_pane_borders = true
    # Pinned because a drawn cursor reverses the cursor cell instead of setting
    # its shape, which stops nvim's insert-mode bar from rendering.
    host_cursor = "native"

    [ui.sidebar.agents]
    rows = [
      [
        "state_icon",
        "state_text",
        { token = "workspace", bold = false },
        { token = "$git_branch", fg = "#957fb8" },
      ],
      [{ token = "$prompt", fg = "#ffffff" }],
    ]

    [ui.sidebar.spaces]
    rows = [
      ["state_icon", "state_text", { token = "workspace", bold = false }],
      [{ token = "branch", fg = "#957fb8" }, "git_status"],
    ]

    [ui.toast]
    # Ghostty suppresses OSC notifications while focused, so completion
    # notifications would be lost. The system backend is unaffected.
    delivery = "${toastDelivery}"
    delay_seconds = 15
  '';
  xdg.configFile."herdr/config.toml".force = true;

  # Reinstall pi's integration on every activation: the command is idempotent
  # and refreshes the generated hook files when Herdr changes its assets.
  home.activation.herdrIntegrations = lib.hm.dag.entryAfter [ "writeBoundary" "installPackages" ] ''
    # Installing pi's binary does not initialize its user directories. Herdr
    # requires this directory even before pi has been launched for the first time.
    run mkdir -p "$HOME/.pi/agent/extensions"
    run ${pkgs.herdr}/bin/herdr integration install pi >/dev/null
  '';

  # Link the checkout so layout edits take effect without a rebuild.
  home.activation.herdrWorktreeLayout = lib.hm.dag.entryAfter [ "writeBoundary" "installPackages" ] ''
    run ${pkgs.herdr}/bin/herdr plugin link "${repoDir}/modules/herdr/worktree-layout" >/dev/null
  '';

  home.file.".pi/agent/extensions/prompt-display.ts".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/modules/herdr/prompt-display.ts";
}
