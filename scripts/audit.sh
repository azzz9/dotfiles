#!/usr/bin/env bash
# The package audit. modules/dotfiles.nix inlines this file into the `dotfiles`
# CLI, which passes five arguments and supplies two helpers, nix_cmd and
# registry_latest:
#
#   audit_packages <repo> <machine> <tmp_dir> <pi_module> <update>
#
# Two sources are checked, because they are pinned in different ways.
#
#   the store   what this machine has, read from the closure of the running
#               system and of its Home Manager generation, against the open
#               issues NixOS/nixpkgs labels "1.severity: security"
#   npm rows    the versions modules/pi.nix pins, against the npm registry's
#               advisories
#
# A store match is a lead, not a verdict. A store path carries a version and
# the issue usually does not, so the report prints both and leaves the call to
# the reader. An npm advisory carries the vulnerable range, so it decides.
#
# scripts/audit-baseline.txt holds what was already read. Only matches outside
# it fail the command, because nixpkgs keeps hundreds of security issues open
# and a few of them always name a base package this machine carries. Text after
# ` #` on a baseline line is for the reader and takes no part in the comparison.

# The store paths this machine has. macOS has no /run/current-system, so there
# the Home Manager generation carries everything. Both reads have to succeed,
# because a closure that only half arrived would report a smaller answer as if
# it were the whole one.
audit_store_paths() {
  local generation
  if [ -e /run/current-system ]; then
    nix_cmd path-info -r /run/current-system || return 1
  fi
  if ! generation="$(nix_cmd build --no-link --print-out-paths --impure \
    "$1#homeConfigurations.$2.activationPackage")"; then
    return 1
  fi
  nix_cmd path-info -r "$generation"
}

# One "<issue number>\t<title>" line per open security issue, every page until
# a short one. A rise past 2000 issues needs the page cap raised.
audit_nixpkgs_issues() {
  local page body count auth=()
  # The issues endpoint, not the search API: a search reader gets 10 requests a
  # minute, which nine pages of issues exhaust on the second run. A token lifts
  # the 60 requests an hour this one gets anonymously.
  if [ -n "${GH_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $GH_TOKEN")
  elif [ -n "${GITHUB_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
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

# "<issue number>\t<package>\t<version>\t<title>" for every store path whose
# package name an open issue names. A store path reads <name>-<version>, but
# both halves may hold hyphens (glibc-2.44-25), so the longest issue name that
# prefixes the basename wins and the rest is the version. Output suffixes are
# dropped by keeping the shortest version per package.
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

# "<name>\t<version>" for every npm row modules/pi.nix pins. The rpiv packages
# are written through the rpiv helper, so their one version line covers both.
audit_npm_specs() {
  local rpiv name spec
  rpiv="$(sed -n 's/^  rpivVersion = "\([0-9][0-9.]*\)";$/\1/p' "$1")"
  if [ -n "$rpiv" ]; then
    while read -r name; do
      printf '%s\t%s\n' "@juicesharp/rpiv-$name" "$rpiv"
    done < <(sed -n 's/.*rpiv "\([^"]*\)".*/\1/p' "$1" | sort -u)
  fi
  while read -r spec; do
    name="${spec#npm:}"
    name="${name%@*}"
    printf '%s\t%s\n' "$name" "${spec##*@}"
  done < <(grep -o 'npm:[A-Za-z0-9@/._-]*@[0-9][0-9A-Za-z.+-]*' "$1" | sort -u)
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

audit_packages() {
  local repo="$1" machine="$2" tmp_dir="$3" pi_module="$4" update="$5"
  local baseline="$repo/scripts/audit-baseline.txt"
  local issues_file="$tmp_dir/dotfiles-audit-issues.tsv"
  local matches_file="$tmp_dir/dotfiles-audit-matches.tsv"
  local current_file="$tmp_dir/dotfiles-audit-current.txt"
  local accepted_file="$tmp_dir/dotfiles-audit-accepted.txt"
  local specs advisories versions findings newest behind
  local paths issues matches newest_count stale_count

  if ! audit_nixpkgs_issues > "$issues_file"; then
    # Reporting "no matches" from a failed fetch is the one wrong answer this
    # audit must never give.
    printf 'dotfiles audit: could not read the nixpkgs security issues from GitHub\n' >&2
    printf 'dotfiles audit: check the network, or wait a minute if the search API rate limit was hit\n' >&2
    exit 1
  fi
  issues="$(wc -l < "$issues_file")"

  if ! paths="$(audit_store_paths "$repo" "$machine" | sed -E 's#.*/##; s#^[a-z0-9]{32}-##' | LC_ALL=C sort -u)"; then
    printf 'dotfiles audit: could not read the store closure for %s\n' "$machine" >&2
    exit 1
  fi
  if [ -z "$paths" ]; then
    printf 'dotfiles audit: the store closure for %s is empty\n' "$machine" >&2
    exit 1
  fi
  printf '%s\n' "$paths" | audit_match_issues "$issues_file" | LC_ALL=C sort > "$matches_file"
  matches="$(wc -l < "$matches_file")"

  specs="$(audit_npm_specs "$pi_module")"
  if ! advisories="$(audit_npm_advisories "$pi_module")"; then
    printf 'dotfiles audit: could not read the npm advisories from the registry\n' >&2
    exit 1
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
    # pin problem, and `dotfiles upgrade` already refuses to make that move.
    if [ "$(printf '%s\n' "$version" "$newest" | sort -V | tail -n 1)" = "$newest" ]; then
      behind="$behind$name $version -> $newest"$'\n'
    fi
  done <<< "$specs"

  {
    awk -F'\t' '{ printf "nixpkgs %s %s\n", $1, $2 }' "$matches_file"
    printf '%s' "$findings" | awk -F'\t' 'NF > 0 { printf "npm %s@%s/%s\n", $1, $2, $3 }'
  } | LC_ALL=C sort -u > "$current_file"

  if [ -f "$baseline" ]; then
    sed -E 's/ +#.*//; /^$/d' "$baseline" | LC_ALL=C sort -u > "$accepted_file"
  else
    : > "$accepted_file"
  fi
  newest_count="$(LC_ALL=C comm -13 "$accepted_file" "$current_file" | wc -l)"
  stale_count="$(LC_ALL=C comm -23 "$accepted_file" "$current_file" | wc -l)"

  printf 'dotfiles audit: store - %s packages, %s open issues, %s matches (%s new)\n' \
    "$(printf '%s\n' "$paths" | wc -l)" "$issues" "$matches" "$newest_count"
  while IFS=$'\t' read -r number name version title; do
    if LC_ALL=C comm -13 "$accepted_file" "$current_file" | grep -qxF "nixpkgs $number $name"; then
      printf 'dotfiles audit:   new   #%s %s %s\n' "$number" "$name" "$version"
      printf 'dotfiles audit:         %s\n' "$title"
      printf 'dotfiles audit:         https://github.com/NixOS/nixpkgs/issues/%s\n' "$number"
    else
      printf 'dotfiles audit:   known #%s %s %s\n' "$number" "$name" "$version"
    fi
  done < "$matches_file"

  printf 'dotfiles audit: npm - %s rows, %s advisories, %s behind\n' \
    "$(printf '%s\n' "$specs" | grep -c . || true)" \
    "$(printf '%s' "$findings" | grep -c . || true)" \
    "$(printf '%s' "$behind" | grep -c . || true)"
  if [ -n "$findings" ]; then
    printf '%s\n' "$findings" | while IFS=$'\t' read -r name version id severity title range; do
      printf 'dotfiles audit:   new   %s %s %s %s\n' "$name" "$version" "$severity" "$range"
      printf 'dotfiles audit:         %s\n' "$title"
      printf 'dotfiles audit:         https://github.com/advisories/GHSA-%s\n' "$id"
    done
  fi
  if [ -n "$behind" ]; then
    printf '%s' "$behind" | while read -r line; do
      printf 'dotfiles audit:   behind %s\n' "$line"
    done
  fi

  if [ "$update" = 1 ]; then
    {
      awk -F'\t' '{ printf "nixpkgs %s %s # %s\n", $1, $2, $3 }' "$matches_file"
      printf '%s' "$findings" | awk -F'\t' 'NF > 0 { printf "npm %s@%s/%s # %s %s\n", $1, $2, $3, $4, $5 }'
    } | LC_ALL=C sort -u > "$baseline"
    printf 'dotfiles audit: wrote %s new; %s recorded lines no longer match\n' \
      "$(wc -l < "$baseline")" "$stale_count"
    printf 'dotfiles audit: review and commit %s to keep the next audit on this set\n' \
      "scripts/audit-baseline.txt"
    exit 0
  fi

  if [ "$newest_count" -gt 0 ]; then
    printf 'dotfiles audit: %s new match(es); read them, then record them with dotfiles audit --update\n' "$newest_count"
    exit 1
  fi
  if [ "$stale_count" -gt 0 ]; then
    printf 'dotfiles audit: %s recorded match(es) no longer apply; prune them with dotfiles audit --update\n' "$stale_count"
  fi
  printf 'dotfiles audit: ok\n'
}
