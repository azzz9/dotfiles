#!/usr/bin/env bash
# The package audit. dotfiles-cli.nix inlines this file into the `dotfiles` CLI,
# which passes arguments and supplies one helper, nix_cmd:
#
#   audit_packages <repo> <machine> <tmp_dir> <pi_module> <update> <declared>
#
# It reports by return code, so `dotfiles audit` can read it as a report.
#
# Three sources are checked, because they are pinned in different ways.
#
#   the store   what this machine has, read from the closure of the running
#               system and of its Home Manager generation, against the open
#               issues NixOS/nixpkgs labels `1.severity: security`. With
#               <declared> set it reads the packages the flake names for the
#               machine instead, because a runner has no store and realising one
#               there costs gigabytes.
#   npm rows    the versions modules/pi.nix pins, against the npm registry's
#               advisories
#   osv         the npm packages pi installed, with their transitive
#               dependencies, against the OSV database. Skipped when pi has
#               left no lockfile.
#
# A store match is a lead, not a verdict. A store path carries a version and
# the issue usually does not, so the report prints both and leaves the call to
# the reader. An npm advisory carries the vulnerable range, so it decides.
#
# Every match is printed. nixpkgs keeps hundreds of security issues open and a
# few of them always name a base package this machine carries, so the list is
# longer than the set of things a person can act on. The report is read after a
# pin bump, not every day.
#
# A declared run reads a subset of the store's names, so it reports fewer
# matches than the store run.

# The running Home Manager generation is the machine's actual set; building the
# checkout is the fallback for a machine that has not applied yet.
audit_store_paths() {
  local generation link
  if [ -e /run/current-system ]; then
    nix_cmd path-info -r /run/current-system || return 1
  fi
  link="${XDG_STATE_HOME:-$HOME/.local/state}/home-manager/gcroots/current-home"
  if [ -e "$link" ]; then
    generation="$(readlink "$link")"
    nix_cmd path-info -r "$generation" || return 1
    return 0
  fi
  if ! generation="$(nix_cmd build --no-link --print-out-paths --impure \
    "$1#homeConfigurations.$2.activationPackage")"; then
    return 1
  fi
  nix_cmd path-info -r "$generation"
}

# The packages the flake names for this machine, in the same "<name>-<version>"
# shape the store paths are reduced to. A machine with no nixosConfigurations
# row contributes only its Home Manager packages.
audit_declared_names() {
  local kind
  for kind in "homeConfigurations.$2.config.home.packages" \
    "nixosConfigurations.$2.config.environment.systemPackages"; do
    nix_cmd eval --impure --json "$1#$kind" --apply 'ps: map (p: p.name) ps' 2>/dev/null || true
  done | jq -r '.[]' | tr '[:upper:]' '[:lower:]' | LC_ALL=C sort -u
}

# One "<issue number>\t<title>" line per open security issue, every page until
# a short one. A rise past 2000 issues needs the page cap raised.
audit_nixpkgs_issues() {
  local page body count token auth=()
  # The issues endpoint, not the search API: a search reader gets 10 requests a
  # minute, which nine pages of issues exhaust on the second run. A token lifts
  # the 60 requests an hour this one gets anonymously.
  if [ -n "${GH_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $GH_TOKEN")
  elif [ -n "${GITHUB_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  elif token="$(timeout 5 gh auth token 2>/dev/null)" && [ -n "$token" ]; then
    auth=(-H "Authorization: Bearer $token")
  fi
  page=1
  while :; do
    if ! body="$(curl -fsS --max-time 30 -H 'User-Agent: dotfiles-audit' "${auth[@]}" \
      "https://api.github.com/repos/NixOS/nixpkgs/issues?labels=1.severity%3A%20security&state=open&per_page=100&page=$page" 2>/dev/null)"; then
      return 1
    fi
    if ! count="$(printf '%s' "$body" | jq -r 'length' 2>/dev/null)"; then
      return 1
    fi
    printf '%s' "$body" | jq -r '.[] | "\(.number)\t\(.title)"'
    if [ "$count" -lt 100 ] || [ "$page" -ge 20 ]; then
      break
    fi
    page=$((page + 1))
  done
}

audit_match_issues() {
  awk -F'\t' '
    NR == FNR {
      name = tolower($2)
      sub(/:.*/, "", name)
      gsub(/^\[[^]]*\] */, "", name)
      sub(/^python3[0-9]*packages\./, "", name)
      gsub(/ +$/, "", name)
      if (name == "") next
      numbers[name] = numbers[name] $1 "\n"
      titles[name, $1] = $2
      next
    }
    {
      n = split($0, part, "-")
      prefix = ""
      best = ""
      for (i = 1; i <= n; i++) {
        prefix = (i == 1 ? part[i] : prefix "-" part[i])
        if (prefix in numbers) best = prefix
      }
      if (best == "") next
      version = substr($0, length(best) + 2)
      if (version == "") version = "-"
      c = split(numbers[best], number, "\n")
      # A sub-package such as poppler-data or cups-progs leaves a hyphenated
      # remainder, so a version that starts with a digit wins over a shorter one.
      digit = (version ~ /^[0-9]/) ? 1 : 0
      for (i = 1; i <= c; i++) {
        if (number[i] == "") continue
        key = best "\t" number[i]
        if (!(key in seen)) {
          seen[key] = version
          seen_digit[key] = digit
        } else if (digit > seen_digit[key] || (digit == seen_digit[key] && length(version) < length(seen[key]))) {
          seen[key] = version
          seen_digit[key] = digit
        }
      }
    }
    END {
      for (key in seen) {
        split(key, part, "\t")
        printf "%s\t%s\t%s\t%s\n", part[2], part[1], seen[key], titles[part[1], part[2]]
      }
    }
  ' "$1" -
}

# "<name>\t<version>" for every npm row modules/pi.nix pins: an `npm:` spec,
# and a tarball row or one of its `deps`, which pin a bare name and version on
# their own lines.
# The latest version published for an npm package; empty on any doubt.
registry_latest() {
  local encoded
  encoded="$(printf '%s' "$1" | sed 's|/|%2F|')"
  curl -fsS --max-time 30 "https://registry.npmjs.org/${encoded}" | jq -r '."dist-tags".latest'
}

audit_npm_specs() {
  local name spec
  {
    while read -r spec; do
      name="${spec#npm:}"
      name="${name%@*}"
      printf '%s\t%s\n' "$name" "${spec##*@}"
    done < <(grep -o 'npm:[A-Za-z0-9@/._-]*@[0-9][0-9A-Za-z.+-]*' "$1" | sort -u)
    awk '
      /^[[:space:]]*name = "/  { split($0, a, "\""); name = a[2]; next }
      /^[[:space:]]*version = "/ { split($0, a, "\""); version = a[2];
        if (name != "") { printf "%s\t%s\n", name, version; name = "" } }
    ' "$1"
  } | sort -u
}

# The registry's advisory answer for the pinned npm rows, as JSON. It names the
# vulnerable ranges, so this is the half that decides on its own.
audit_npm_advisories() {
  local body
  body="$(audit_npm_specs "$1" | jq -R -s '
    split("\n") | map(select(length > 0) | split("\t") | {(.[0]): [.[1]]}) | add // {}')"
  curl -fsS --max-time 30 -X POST -H 'Content-Type: application/json' \
    -d "$body" "https://registry.npmjs.org/-/npm/v1/security/advisories/bulk"
}

# OSV covers the npm packages pi installed with their transitive dependencies,
# which the registry advisory read above does not see.
audit_osv_findings() {
  local lockfile="${HOME}/.pi/agent/npm/package-lock.json"
  if [ ! -f "$lockfile" ]; then
    return 0
  fi
  osv-scanner scan source --lockfile "$lockfile" --format json 2>/dev/null |
    jq -r '.results[]?.packages[]? | .package as $p | .vulnerabilities[]? | "osv \(.id) \($p.name)@\($p.version)"' 2>/dev/null || true
}

audit_packages() {
  local repo="$1" machine="$2" tmp_dir="$3" pi_module="$4" declared="$5"
  local issues_file="$tmp_dir/dotfiles-audit-issues.tsv"
  local matches_file="$tmp_dir/dotfiles-audit-matches.tsv"
  local specs advisories versions findings osv newest behind source
  local names issues matches

  if ! audit_nixpkgs_issues > "$issues_file"; then
    # Reporting "no matches" from a failed fetch is the one wrong answer this
    # audit must never give.
    printf 'dotfiles audit: could not read the nixpkgs security issues from GitHub\n' >&2
    printf 'dotfiles audit: check the network, or wait a minute if the search API rate limit was hit\n' >&2
    return 1
  fi
  issues="$(wc -l < "$issues_file")"

  source=store
  if [ "$declared" = 1 ]; then
    source=declared
    if ! names="$(audit_declared_names "$repo" "$machine")"; then
      printf 'dotfiles audit: could not read the declared packages for %s\n' "$machine" >&2
      return 1
    fi
  elif ! names="$(audit_store_paths "$repo" "$machine" | sed -E 's#.*/##; s#^[a-z0-9]{32}-##')"; then
    printf 'dotfiles audit: could not read the store closure for %s\n' "$machine" >&2
    return 1
  fi
  names="$(printf '%s\n' "$names" | LC_ALL=C sort -u)"
  if [ -z "$names" ]; then
    printf 'dotfiles audit: read no %s packages for %s\n' "$source" "$machine" >&2
    return 1
  fi
  printf '%s\n' "$names" | audit_match_issues "$issues_file" | LC_ALL=C sort > "$matches_file"
  matches="$(wc -l < "$matches_file")"

  specs="$(audit_npm_specs "$pi_module")"
  if ! advisories="$(audit_npm_advisories "$pi_module")"; then
    printf 'dotfiles audit: could not read the npm advisories from the registry\n' >&2
    return 1
  fi
  versions="$(printf '%s\n' "$specs" | jq -R -s '
    split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}')"
  findings="$(printf '%s' "$advisories" | jq -r --argjson versions "$versions" '
    to_entries[] | .key as $name | ($versions[$name] // "-") as $version
    | .value[] | [$name, $version, (.id | tostring), .severity, .title, .vulnerable_versions] | @tsv')"

  behind=""
  while IFS=$'\t' read -r name version; do
    if [ -z "$name" ]; then
      continue
    fi
    newest="$(registry_latest "$name" 2>/dev/null || true)"
    if [ -z "$newest" ] || [ "$newest" = "null" ] || [ "$newest" = "$version" ]; then
      continue
    fi
    # Only a newer version is worth naming. A registry that went backwards is a
    # pin problem, and `bump-pins.sh` already refuses to make that move.
    if [ "$(printf '%s\n' "$version" "$newest" | sort -V | tail -n 1)" = "$newest" ]; then
      behind="$behind$name $version -> $newest"$'\n'
    fi
  done <<< "$specs"

  osv="$(audit_osv_findings)"

  printf 'dotfiles audit: %s - %s packages, %s open issues, %s matches\n' \
    "$source" "$(printf '%s\n' "$names" | wc -l)" "$issues" "$matches"
  while IFS=$'\t' read -r number name version title; do
    printf 'dotfiles audit:   #%s %s %s\n' "$number" "$name" "$version"
    printf 'dotfiles audit:     %s\n' "$title"
    printf 'dotfiles audit:     https://github.com/NixOS/nixpkgs/issues/%s\n' "$number"
  done < "$matches_file"

  printf 'dotfiles audit: npm - %s rows, %s advisories, %s behind\n' \
    "$(printf '%s\n' "$specs" | grep -c . || true)" \
    "$(printf '%s' "$findings" | grep -c . || true)" \
    "$(printf '%s' "$behind" | grep -c . || true)"
  if [ -n "$findings" ]; then
    printf '%s\n' "$findings" | while IFS=$'\t' read -r name version id severity title range; do
      printf 'dotfiles audit:   %s %s %s %s\n' "$name" "$version" "$severity" "$range"
      printf 'dotfiles audit:         %s\n' "$title"
      printf 'dotfiles audit:         https://github.com/advisories/GHSA-%s\n' "$id"
    done
  fi
  if [ -n "$behind" ]; then
    printf '%s' "$behind" | while read -r line; do
      printf 'dotfiles audit:   behind %s\n' "$line"
    done
  fi

  if [ -n "$osv" ]; then
    printf 'dotfiles audit: osv - %s advisory(ies)\n' "$(printf '%s\n' "$osv" | grep -c .)"
    printf '%s\n' "$osv" | while read -r _ id pkg; do
      printf 'dotfiles audit:   %s %s\n' "$id" "$pkg"
    done
  fi

  return 0
}
