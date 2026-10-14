{ pkgs, ... }:
{
  # gh-dash, a terminal dashboard for GitHub pull requests and issues,
  # https://gh-dash.dev
  home.packages = [ pkgs.gh-dash ];

  # The same package is a gh extension, so `gh dash` finds it through gh's own
  # extension lookup. Home Manager links the package's bin directory under
  # ~/.local/share/gh/extensions and makes that directory read-only, so a later
  # `gh extension install` needs a path of its own.
  programs.gh.extensions = [ pkgs.gh-dash ];

  # prSections and issueSections stay out, because a section list replaces the
  # set gh-dash ships with (My Pull Requests, Needs My Review, Involved).
  xdg.configFile."gh-dash/config.yml".text = ''
    # Managed by Home Manager (modules/gh-dash.nix); do not edit directly.

    # The checkout command and the lazygit keybinding both read the local path
    # from here. The tilde survives: checkout expands it, and a keybinding
    # command runs in a shell.
    repoPaths:
      ":owner/:repo": "~/src/github.com/:owner/:repo"

    # delta renders the diff that `d` opens, as it renders diffs for lazygit in
    # modules/lazygit.nix. gh-dash turns this into GH_PAGER=delta --paging always.
    pager:
      diff: delta

    # A universal command sees only the directory gh-dash was launched in, so
    # this repeats per view to open the repository of the selected row.
    keybindings:
      prs:
        - key: g
          name: lazygit
          command: cd {{.RepoPath}} && lazygit
      issues:
        - key: g
          name: lazygit
          command: cd {{.RepoPath}} && lazygit

    # Kanagawa Dragon, the palette modules/nvim/lua/plugins/kanagawa.lua gives
    # the editor. inverted colors the labels and the pills, so it takes the
    # #101010 background modules/ghostty.nix sets for the terminal instead of
    # the theme's own #181616.
    theme:
      colors:
        text:
          primary: "#c5c9c5"
          secondary: "#a6a69c"
          inverted: "#101010"
          faint: "#625e5a"
          warning: "#c4746e"
          success: "#87a987"
          error: "#e46876"
          actor: "#8ba4b0"
        background:
          selected: "#393836"
        border:
          primary: "#a292a3"
          secondary: "#625e5a"
          faint: "#282727"
  '';
  xdg.configFile."gh-dash/config.yml".force = true;
}
