#!/usr/bin/env bash

usage() {
  cat <<'USAGE'
usage: wt-clean <branch> [--repo PATH] [--force]

Removes the checkout of <branch>, closes its Herdr workspace, and deletes the
branch. It removes nothing unless another local branch contains the branch tip,
or a GitHub pull request for it is merged at that commit. Run it inside a Herdr
pane, because the workspace goes with the checkout.

  --repo PATH   repository to clean, default the current one
  --force       discard uncommitted work and delete the branch without proof

Exit 0 leaves nothing behind, exit 1 stops and names what is still there, and
exit 2 is a bad invocation.
USAGE
}

die() {
  printf 'wt-clean: %s\n' "$*" >&2
  exit 1
}

arg_error() {
  printf 'wt-clean: %s\n' "$*" >&2
  exit 2
}

branch=""
repo=""
force=0
while (($#)); do
  case $1 in
    --repo)
      (($# >= 2)) || arg_error "--repo needs a path"
      repo=$2
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      printf 'wt-clean: unknown option %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      [[ -z $branch ]] || arg_error "one branch per run"
      branch=$1
      shift
      ;;
  esac
done
[[ -n $branch ]] || {
  usage >&2
  exit 2
}

if [[ -z $repo ]]; then
  repo=$(git rev-parse --show-toplevel 2>/dev/null) ||
    arg_error "not inside a git repository; pass --repo <path>"
fi
primary=$(git -C "$repo" worktree list --porcelain | sed -n '1s/^worktree //p')
[[ -n $primary ]] || die "cannot find the primary checkout of $repo"
ref="refs/heads/$branch"

has_ref=0
if git -C "$primary" show-ref --verify --quiet "$ref"; then
  has_ref=1
fi

path=""
if ((has_ref)); then
  checkouts=$(git -C "$primary" worktree list --porcelain |
    awk -v ref="$ref" '
      /^worktree / { checkout = substr($0, 10) }
      /^branch / && $2 == ref { print checkout }
    ')
  if [[ -n $checkouts ]]; then
    count=$(printf '%s\n' "$checkouts" | wc -l | tr -d ' ')
    ((count == 1)) || die "$branch is checked out in $count worktrees; nothing was removed"
    path=$checkouts
  fi
fi

if ((!has_ref)) && [[ -z $path ]]; then
  printf 'wt-clean: %s is already gone\n' "$branch"
  exit 0
fi

primary_head=$(git -C "$primary" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
if [[ -z $path && $primary_head == "$branch" ]]; then
  die "$branch is checked out by the primary checkout"
fi
if [[ -n $path && $path == "$primary" ]]; then
  die "$branch is checked out at the primary checkout"
fi
if [[ -n $path && ${HERDR_ENV:-} != 1 ]]; then
  die "run this inside a Herdr pane; a workspace may still hold $path"
fi

dirty=""
if [[ -n $path ]]; then
  [[ -d $path ]] || die "the checkout of $branch is missing: $path"
  dirty=$(git -C "$path" status --porcelain)
fi

herdr_ws=""
if [[ ${HERDR_ENV:-} == 1 ]] && [[ -n $path ]]; then
  command -v herdr >/dev/null 2>&1 ||
    die "herdr is not on PATH; the workspace state of $path is unknown"
  list=$(herdr worktree list --cwd "$primary" 2>/dev/null) ||
    die "herdr did not answer; the workspace state of $path is unknown"
  herdr_ws=$(jq -r --arg p "$path" \
    '.result.worktrees[] | select(.path == $p) | .open_workspace_id // empty' <<<"$list" |
    head -n 1) || die "cannot read the herdr worktree list"
fi

working=""
if [[ -n $herdr_ws ]]; then
  working=$(herdr agent list 2>/dev/null |
    jq -r --arg w "$herdr_ws" \
      '.result.agents[] | select(.workspace_id == $w and .agent_status == "working") | .pane_id') ||
    die "cannot read the herdr agent list; nothing was removed"
fi

# Deleting the branch is the last step, so a locked ref has to stop the run
# before the checkout and the workspace go.
if ((has_ref)); then
  common=$(git -C "$primary" rev-parse --git-common-dir)
  case $common in
    /*) ;;
    *) common="$primary/$common" ;;
  esac
  if [[ -e "$common/refs/heads/$branch.lock" || -e "$common/packed-refs.lock" ]]; then
    die "the ref store is locked for $branch; nothing was removed"
  fi
fi

# A local branch is checked first because it needs no network. The pull request
# covers squash and rebase merges, where the local tip never becomes an ancestor
# of the merge target.
proof=""
tip=""
gh_state=skipped
gh_other=""
if ((has_ref)); then
  tip=$(git -C "$primary" rev-parse "$ref")
  others=$(git -C "$primary" for-each-ref --contains "$tip" --format='%(refname)' refs/heads |
    awk -v r="$ref" '$0 != r')
  if [[ -n $others ]]; then
    first=${others%%$'\n'*}
    proof="local branch ${first#refs/heads/}"
  elif command -v gh >/dev/null 2>&1 &&
    git -C "$primary" remote get-url origin >/dev/null 2>&1; then
    prs=""
    if prs=$(cd "$primary" && gh pr list --head "$branch" --state all \
      --json number,state,mergedAt,headRefOid --limit 20 2>/dev/null); then
      gh_state=ok
      merged=$(jq -r --arg tip "$tip" \
        '[.[] | select(.state == "MERGED" and .headRefOid == $tip)][0].number // empty' <<<"$prs")
      if [[ -n $merged ]]; then
        proof="merged PR #$merged"
      else
        gh_other=$(jq -r 'if length == 0 then "no pull request"
          else ([.[] | "\(.state) #\(.number) at \(.headRefOid[0:7])"] | join(", ")) end' <<<"$prs")
      fi
    else
      gh_state=unknown
    fi
  fi
fi

blocked=0
if [[ -n $dirty ]] && ((!force)); then
  blocked=1
fi
if [[ -n $working ]] && ((!force)); then
  blocked=1
fi
if ((has_ref)) && [[ -z $proof ]] && ((!force)); then
  blocked=1
fi

if ((blocked)); then
  printf 'wt-clean: %s stays put; nothing was removed\n' "$branch" >&2
  if [[ -n $dirty ]]; then
    printf '  uncommitted: %s path(s)\n' "$(wc -l <<<"$dirty" | tr -d ' ')" >&2
  fi
  if [[ -n $working ]]; then
    printf '  agent working: %s\n' "$working" >&2
  fi
  if ((has_ref)) && [[ -z $proof ]]; then
    printf '  commit %s is not in another local branch\n' "${tip:0:7}" >&2
    case $gh_state in
      ok) printf '  github: %s\n' "${gh_other:-no pull request}" >&2 ;;
      unknown) printf '  github: could not read the pull request\n' >&2 ;;
      skipped) printf '  github: skipped, gh is missing or origin is not a remote\n' >&2 ;;
    esac
  fi
  printf '  commit the work, merge it, or pass --force to discard\n' >&2
  exit 1
fi

forced=()
if ((force)); then
  if [[ -n $dirty ]]; then
    forced+=("discarded $(wc -l <<<"$dirty" | tr -d ' ') uncommitted path(s)")
  fi
  if [[ -n $working ]]; then
    forced+=("stopped the agent working in $herdr_ws")
  fi
  if ((has_ref)) && [[ -z $proof ]]; then
    forced+=("deleted $branch without a merged pull request")
  fi
fi

if [[ -n $herdr_ws ]]; then
  if ((force)); then
    herdr worktree remove --workspace "$herdr_ws" --force >/dev/null ||
      die "herdr refused to remove $herdr_ws; the branch is untouched"
  else
    herdr worktree remove --workspace "$herdr_ws" >/dev/null ||
      die "herdr refused to remove $herdr_ws; the branch is untouched"
  fi
  herdr workspace close "$herdr_ws" >/dev/null 2>&1 || true
  printf 'removed workspace %s\n' "$herdr_ws"
elif [[ -n $path ]]; then
  if ((force)); then
    git -C "$primary" worktree remove --force "$path" ||
      die "git refused to remove $path; the branch is untouched"
  else
    git -C "$primary" worktree remove "$path" ||
      die "git refused to remove $path; the branch is untouched"
  fi
  printf 'removed checkout %s\n' "$path"
else
  printf 'no checkout for %s\n' "$branch"
fi

if ((has_ref)); then
  if [[ -n $herdr_ws ]]; then
    git -C "$primary" branch -D -- "$branch" >/dev/null ||
      die "the checkout and workspace are gone but $branch remains; restore with git worktree add $path $branch and herdr worktree open --path $path"
  else
    git -C "$primary" branch -D -- "$branch" >/dev/null ||
      die "the checkout is gone but $branch remains; restore with git worktree add $path $branch"
  fi
  printf 'deleted branch %s\n' "$branch"
fi

if ((${#forced[@]})); then
  for note in "${forced[@]}"; do
    printf 'forced: %s\n' "$note"
  done
fi

exit 0
