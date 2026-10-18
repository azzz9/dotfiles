# Hermes Agent, https://github.com/NousResearch/hermes-agent
#
# Only nix-server imports this module (see the machine row in flake.nix).
# The module is the Home Manager one, because the gateway is a systemd USER
# service, and because the state, the credentials and the cron jobs belong to
# azzz rather than to the system.
{
  config,
  hermesAgent,
  lib,
  pkgs,
  ...
}:

{
  imports = [ hermesAgent.homeManagerModules.default ];

  # The `hermes` CLI on PATH, and HERMES_HOME with it, so an interactive shell
  # reads the same state as the service.
  programs.hermes-agent.enable = true;

  services.hermes-agent = {
    enable = true;
    gateway.enable = true;

    # The generated unit's PATH holds store paths only, while the installer's
    # worker PATH reached further. Each entry below restores one command that
    # only the installer's environment provided:
    #
    #   systemd  systemd-run, which scopes each cron worker into a transient
    #            unit. The installer's unit needed a hand-written drop-in
    #            (10-nixos-path.conf) for exactly that reason.
    #   curl     the agent's terminal tool has run curl in this machine's
    #            session history.
    #
    # The installer's ~/.hermes/tools also kept a Python on the worker PATH,
    # because hermes prepends any HERMES_HOME/tools/*/bin it finds, and nothing
    # replaces it once that tree is retired. Adding pkgs.python3 here does not
    # work: home.packages already carries pkgs.python3.withPackages, and buildEnv
    # refuses two paths that both ship bin/python3. Use that same derivation if a
    # shell command ever needs an interpreter.
    extraPackages = [
      pkgs.systemd
      pkgs.curl
    ];

    # The unit it replaces had WorkingDirectory=/home/azzz/.hermes. The
    # module also writes workingDirectory to config.yaml as terminal.cwd, and
    # ~/.hermes/config.yaml sets terminal.cwd to ".", so the setting below
    # keeps that value instead of letting the module write the absolute path.
    workingDirectory = "${config.home.homeDirectory}/.hermes";
    settings.terminal.cwd = ".";

    # `environment` and `environmentFiles` stay empty on purpose. Activation
    # rewrites ~/.hermes/.env from the start whenever either is set, and that
    # file is 27 KB of hand-managed secrets. This repo keeps machine-local
    # secrets out of Nix the same way for pi and herdr.
  };

  # Herdr's hermes integration reports an interactive session to herdr, so a pane
  # can be resumed after a server restart. modules/herdr.nix reinstalls pi's
  # integration the same way; this one lives here because hermes runs on
  # nix-server alone. It runs after hermesAgentSetup, which is what creates
  # $HERMES_HOME/plugins on a machine that has never started hermes. The install
  # also enables the plugin in config.yaml, and this module leaves
  # plugins.enabled undeclared on purpose: a Nix-declared list would win over the
  # file and take away `hermes plugins enable` for every other plugin.
  home.activation.herdrHermesIntegration =
    lib.hm.dag.entryAfter [ "writeBoundary" "installPackages" "hermesAgentSetup" ]
      ''
        run ${pkgs.herdr}/bin/herdr integration install hermes >/dev/null
      '';

  # Upstream's unit is Restart=always, and hermes exits 78 on a permanent
  # refusal (GATEWAY_FATAL_CONFIG_EXIT_CODE, for example a profile the
  # multiplexer refuses). The unit this module replaces carried this backstop,
  # so such a refusal parks the unit instead of restarting it.
  systemd.user.services.hermes-agent.Service.RestartPreventExitStatus = 78;

  # systemd sends SIGTERM on stop, and with no marker the gateway reads that as
  # an unexpected kill: it exits 1, and systemd records "Failed with result
  # exit-code" for a stop that was intentional. The installer's launcher wrote
  # that marker from ExecStop, upstream's module does not, and the installed
  # `hermes` wrapper has no --run-module flag, so the hook starts the module
  # through the sealed venv instead. The leading dash keeps a broken hook from
  # blocking the stop.
  systemd.user.services.hermes-agent.Service.ExecStop =
    "-${config.programs.hermes-agent.package.hermesVenv}/bin/python3 -m gateway.systemd_stop_mark";
}
