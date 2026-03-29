{ ... }:
{
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      editor = "nvim";
      prompt = "enabled";
      prefer_editor_prompt = "enabled";
      pager = "less -FRX";
      color_labels = "enabled";
      aliases = {
        co = "pr checkout";
        prs = "pr status";
        prv = "pr view";
        prw = "pr view --web";
        prc = "pr create --fill";
        pcd = "pr checks";
        rv = "repo view --web";
      };
    };
  };

  xdg.configFile."gh/config.yml".force = true;
}
