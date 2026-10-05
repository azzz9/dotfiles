{ config, lib, pkgs, repoDir, ... }:
let
  toastDelivery = "system";
in
{
  # herdr agent multiplexer, https://github.com/ogulcancelik/herdr
  home.packages = [ pkgs.herdr ];

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

  home.file.".pi/agent/extensions/prompt-display.ts".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/modules/herdr/prompt-display.ts";
}
