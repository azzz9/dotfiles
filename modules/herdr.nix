{ lib, pkgs, ... }:
let
  toastDelivery = "system";
  isWsl =
    pkgs.stdenv.hostPlatform.isLinux
    && (builtins.getEnv "WSL_DISTRO_NAME" != "" || builtins.pathExists /run/WSL);

  windowsNotifySend = pkgs.writeShellScriptBin "notify-send" ''
    set -euo pipefail

    if [ "$#" -gt 0 ] && [ "$1" = "--" ]; then
      shift
    fi

    title="''${1-}"
    body="''${2-}"
    if [ -z "$title" ]; then
      exit 2
    fi

    title_b64="$(${pkgs.coreutils}/bin/printf '%s' "$title" | ${pkgs.coreutils}/bin/base64 -w0)"
    body_b64="$(${pkgs.coreutils}/bin/printf '%s' "$body" | ${pkgs.coreutils}/bin/base64 -w0)"
    ps_script=$(cat <<'POWERSHELL'
$ErrorActionPreference = "Stop"
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$title = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__TITLE_B64__'))
$body = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__BODY_B64__'))
$escapedTitle = [System.Security.SecurityElement]::Escape($title)
$escapedBody = [System.Security.SecurityElement]::Escape($body)
$bodyMarkup = if ([string]::IsNullOrEmpty($body)) { "" } else { "<text>$escapedBody</text>" }
$xmlText = "<toast><visual><binding template=""ToastGeneric""><text>$escapedTitle</text>$bodyMarkup</binding></visual></toast>"

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($xmlText)
$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe").Show($toast)
POWERSHELL
)
    ps_script="''${ps_script//__TITLE_B64__/$title_b64}"
    ps_script="''${ps_script//__BODY_B64__/$body_b64}"
    encoded="$(${pkgs.coreutils}/bin/printf '%s' "$ps_script" | ${pkgs.glibc.bin}/bin/iconv -f UTF-8 -t UTF-16LE | ${pkgs.coreutils}/bin/base64 -w0)"

    exec powershell.exe -NoLogo -NoProfile -NonInteractive -OutputFormat Text -EncodedCommand "$encoded"
  '';
in
{
  # herdr agent multiplexer, https://github.com/ogulcancelik/herdr
  home.packages = with pkgs; [
    herdr
  ] ++ lib.optional isWsl windowsNotifySend;

  # Herdr's system notification backend skips notify-send when no display
  # variable is set. WSLg normally supplies DISPLAY; this keeps the toast
  # bridge working in plain WSL sessions too.
  home.sessionVariables = lib.mkIf isWsl {
    DISPLAY = ":0";
  };

  xdg.configFile."herdr/config.toml".text = ''
    # Managed by Home Manager (modules/herdr.nix); do not edit directly.

    onboarding = false

    [theme]
    name = "kanagawa"

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
    # "auto" resolves to drawn on WSL, which reverses the cursor cell instead of
    # setting its shape, so nvim's insert-mode bar never renders.
    host_cursor = "native"

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
    ${pkgs.herdr}/bin/herdr integration install pi >/dev/null
  '';
}
