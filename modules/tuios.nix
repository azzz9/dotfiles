{ ... }:
{
  # tuios terminal multiplexer, https://github.com/Gaurav-Gosain/tuios
  # Linux and macOS both read ~/.config/tuios/config.toml (XDG).
  xdg.configFile."tuios/config.toml" = {
    source = ./tuios/config.toml;
    force = true;
  };
}
