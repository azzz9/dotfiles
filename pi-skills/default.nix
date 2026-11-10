# The pi package this repository ships: the rules pi loads on every turn
# (AGENTS.md, APPEND_SYSTEM.md), the skills, and the extensions. pi loads the
# store path this builds in place.
#
# Four skills follow their upstream repositories. Each one's source is a
# `flake = false` input in flake.nix, so flake.lock pins it and `nix flake
# update` moves it. The build copies the part of the upstream tree the skill
# uses into skills/<name>/, applies upstream/<name>/local.patch with
# `git apply`, and adds upstream/<name>/VENDOR.md. A patch that no longer
# applies to the pinned upstream fails this build, and so every check.
{ pkgs, upstreams }:
let
  inherit (pkgs) lib;
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.difference ./. (lib.fileset.unions [ ./default.nix ./upstream ]);
  };
  # What each tracked skill takes from its upstream tree. `take FROM [TO]`
  # copies FROM (relative to the upstream root) to TO (relative to the skill,
  # default FROM's basename); `drop PATH` removes a copied path the skill does
  # not ship. VENDOR.md says why each part is left out.
  tracked = {
    herdr = ''
      take skills/herdr/SKILL.md
      take LICENSE
    '';
    imozuru = ''
      take skills/imozuru/SKILL.md
      take skills/imozuru/references
      take skills/imozuru/scripts
      drop scripts/make_guide_shots.py
      drop scripts/make_textures.py
      take examples/demo examples/demo
      take LICENSE
    '';
    retro = ''
      take skills/engineering/retro/SKILL.md
      take LICENSE
    '';
    yomiyasu = ''
      take skills/yomiyasu/SKILL.md
      take skills/yomiyasu/LICENSE
      take skills/yomiyasu/UNICODE-LICENSE.txt
      take skills/yomiyasu/references
      take skills/yomiyasu/scripts
      drop scripts/yomiyasu_hook.py
    '';
  };
  assemble = name: rules: ''
    upstream=${upstreams.${name}}
    skill=$out/skills/${name}
    mkdir -p "$skill"
    take() {
      local to="''${2:-$(basename "$1")}"
      mkdir -p "$(dirname "$skill/$to")"
      cp -r "$upstream/$1" "$skill/$to"
      chmod -R u+w "$skill/$to"
    }
    drop() { rm -r "''${skill:?}/$1"; }
    ${rules}
    if ! git -C "$skill" apply --whitespace=nowarn ${./upstream + "/${name}/local.patch"}; then
      echo "pi-skills: upstream/${name}/local.patch does not apply to $upstream" >&2
      exit 1
    fi
    cp ${./upstream + "/${name}/VENDOR.md"} "$skill/VENDOR.md"
  '';
in
pkgs.runCommand "pi-skills" { nativeBuildInputs = [ pkgs.git ]; } ''
  export HOME=$TMPDIR
  cp -r ${src} $out
  chmod -R u+w $out
  ${lib.concatStrings (lib.mapAttrsToList assemble tracked)}
''
