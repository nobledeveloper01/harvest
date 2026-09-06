#!/usr/bin/env bash
#
# Documentation gate.
#
# The point of this script is the last check: it fails when code changed and
# nothing recorded why. Documentation that is only a convention decays; a
# convention with a gate in front of it does not.
#
# Run by `make doc-check`, by CI, and by the pre-commit hook.
set -uo pipefail

cd "$(dirname "$0")/.."

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
fail=0
warn=0

err()  { printf '%s✗%s %s\n' "$RED" "$OFF" "$1"; fail=$((fail+1)); }
note() { printf '%s!%s %s\n' "$YEL" "$OFF" "$1"; warn=$((warn+1)); }
ok()   { printf '%s✓%s %s\n' "$GRN" "$OFF" "$1"; }

# --- 1. The required documents exist, and are actually tracked -------------
#
# "Exists on disk" is not the check that matters. `docs/*` is ignored with an
# allow-list, so a new document lands in the working tree, passes every gate,
# gets `git add -A`'d, reports a clean commit — and is not in the repository.
# That happened to the feature backlog: written, gated, committed and absent
# from GitHub for a day. The gate now asks git, not the filesystem.
REQUIRED="README.md DESIGN.md CHANGELOG.md PHASE
          docs/ROADMAP.md docs/JOURNAL.md docs/00-PRODUCT-STATEMENT.md
          docs/FEATURE-BACKLOG.md"

for f in $REQUIRED; do
  [ -f "$f" ] || err "missing $f"
done
[ "$fail" -eq 0 ] && ok "all required documents present"

if [ -d .git ]; then
  untracked=""
  for f in $REQUIRED; do
    [ -f "$f" ] || continue
    git ls-files --error-unmatch "$f" >/dev/null 2>&1 || untracked="$untracked $f"
  done
  if [ -n "$untracked" ]; then
    err "present but NOT TRACKED by git — .gitignore is swallowing them:$untracked"
  else
    ok "every required document is tracked, not just present"
  fi

  # Same trap, one level down: the screenshots the README embeds.
  if [ -d docs/screenshots ]; then
    shots=$(ls docs/screenshots/*.png 2>/dev/null | wc -l | tr -d ' ')
    tracked=$(git ls-files docs/screenshots | wc -l | tr -d ' ')
    if [ "$shots" != "$tracked" ]; then
      err "docs/screenshots: $shots on disk, $tracked tracked — the README would render broken images on GitHub"
    else
      ok "$tracked screenshots tracked"
    fi

    # And the other direction: a screenshot nobody shows.
    #
    # Capturing one and forgetting to reference it is the same failure as the
    # untracked backlog — the work is done, the gate is green, and the reader
    # never sees it. Four accumulated before anyone noticed. Every reference in
    # both READMEs counts, so a screenshot used only by the server's page is
    # not reported as orphaned.
    orphans=""
    for shot in docs/screenshots/*.png; do
      base=$(basename "$shot")
      if ! grep -qR --include='*.md' "$base" . 2>/dev/null; then
        orphans="$orphans $base"
      fi
    done
    if [ -n "$orphans" ]; then
      err "screenshots nothing references — captured, committed, and invisible:$orphans"
    else
      ok "every screenshot is referenced by a document"
    fi

    # And the direction nothing was watching: whether they still show the app.
    #
    # "Tracked" and "referenced" are both true of a picture two months out of
    # date. Every screenshot in this repository was once thirteen commits and
    # one whole feature behind — the daylight switch had been added to three
    # app bars and appeared in none of them — and the gate was green the entire
    # time, because it was counting files.
    #
    # A warning, not a failure. Most commits under app/lib change nothing you
    # can see, and a gate that goes red on every one of them is a gate people
    # learn to run with --no-verify. What it can do is refuse to let the drift
    # go unmentioned.
    code=$(git log -1 --format=%ct -- app/lib 2>/dev/null || echo 0)
    shots=$(git log -1 --format=%ct -- docs/screenshots 2>/dev/null || echo 0)
    if [ "${code:-0}" -gt "${shots:-0}" ]; then
      behind=$(git rev-list --count "$(git log -1 --format=%H -- docs/screenshots)"..HEAD -- app/lib 2>/dev/null || echo '?')
      [ "$behind" = 1 ] && commits=commit || commits=commits
      note "the screenshots are $behind $commits of app/lib behind — retake any screen that moved:  make screenshot N=<name>"
    else
      ok "the screenshots are no older than the last change to the app"
    fi
  fi
fi

# --- 2. PHASE is a number, and it is the phase the roadmap calls current ----
#
# "The roadmap has a section for it" was the whole check, and it stays true the
# moment a phase is marked cleared and PHASE is not moved on — which is the only
# way these two ever disagree. Exactly one heading carries **current**, and it
# is the one PHASE names.
if [ -f PHASE ]; then
  phase=$(tr -d '[:space:]' < PHASE)
  if ! [[ "$phase" =~ ^[0-9]+$ ]]; then
    err "PHASE is '$phase', which is not a number"
  elif ! grep -qE "^## Phase $phase( |$|—)" docs/ROADMAP.md 2>/dev/null; then
    err "PHASE says $phase but docs/ROADMAP.md has no '## Phase $phase' section"
  else
    current_count=$(grep -cE '^## Phase [0-9]+ .*\*\*current\*\*' docs/ROADMAP.md 2>/dev/null || true)
    current_phase=$(grep -E '^## Phase [0-9]+ .*\*\*current\*\*' docs/ROADMAP.md 2>/dev/null \
      | head -1 | sed -E 's/^## Phase ([0-9]+).*/\1/')
    if [ "$current_count" -eq 0 ]; then
      err "no phase in docs/ROADMAP.md is marked **current** — PHASE says $phase"
    elif [ "$current_count" -gt 1 ]; then
      err "$current_count phases are marked **current** in docs/ROADMAP.md; exactly one may be"
    elif [ "$current_phase" != "$phase" ]; then
      err "PHASE says $phase but docs/ROADMAP.md marks Phase $current_phase as **current**"
    else
      ok "PHASE $phase is the phase the roadmap calls current"
    fi
  fi
fi

# --- 3. Every roadmap phase declares an exit gate ---------------------------
if [ -f docs/ROADMAP.md ]; then
  missing_gates=""
  while IFS= read -r line; do
    p="${line#\#\# Phase }"; p="${p%% *}"
    # Grab the section and look for an exit gate heading in it.
    if ! awk -v want="$line" '
        $0 == want {inside=1; next}
        /^## / {inside=0}
        inside && /^\*\*Exit gate\*\*/ {found=1}
        END {exit !found}' docs/ROADMAP.md; then
      missing_gates="$missing_gates $p"
    fi
  done < <(grep -E '^## Phase [0-9]+' docs/ROADMAP.md)
  if [ -n "$missing_gates" ]; then
    err "roadmap phases with no **Exit gate**:$missing_gates"
  else
    ok "every roadmap phase declares an exit gate"
  fi
fi

# --- 4. The changelog has somewhere to put the next change -----------------
if [ -f CHANGELOG.md ] && ! grep -q '^## \[Unreleased\]' CHANGELOG.md; then
  err "CHANGELOG.md has no '## [Unreleased]' section to write into"
elif [ -f CHANGELOG.md ]; then
  ok "CHANGELOG.md has an Unreleased section"
fi

# --- 5. ADRs are well-formed, numbered without gaps ------------------------
if [ -d docs/adr ]; then
  n=0; expected=1; adr_bad=""
  for f in $(ls docs/adr/[0-9]*.md 2>/dev/null | sort); do
    n=$((n+1))
    base=$(basename "$f")
    num=$((10#${base%%-*}))
    [ "$num" -eq "$expected" ] || adr_bad="$adr_bad $base(expected $expected)"
    expected=$((num+1))
    # An ADR on disk is not an ADR anybody can read. This gate has always
    # checked that the required documents are tracked and never checked it of
    # the ADRs — the same allow-list blind spot it exists to prevent, found in
    # the sibling project first.
    git ls-files --error-unmatch "$f" >/dev/null 2>&1 \
      || err "$base is present but not tracked by git — nobody outside this machine can read it"
    for section in '^\*\*Status:\*\*' '^## Context' '^## Decision' '^## Consequences'; do
      grep -qE "$section" "$f" || err "$base is missing a '$(echo "$section" | tr -d '^\\*#')' section"
    done
  done
  [ -n "$adr_bad" ] && err "ADR numbering has gaps or duplicates:$adr_bad"
  [ "$n" -gt 0 ] && ok "$n ADRs, well-formed and numbered consecutively"

  # --- 5b. Nothing cites an ADR that was never written ---------------------
  #
  # "See ADR-0002" in a Makefile comment reads exactly like a settled decision
  # somebody can go and check. When the file does not exist the reader either
  # concludes the decision is undocumented, or — worse — trusts the citation
  # and never looks. A dangling reference is more misleading than no reference,
  # because it claims a rationale exists.
  #
  # Found by this gate on its first run: `make domain-purity` cited ADR-0002
  # while the directory held only ADR-0001.
  dangling=""
  for ref in $(grep -rhoE 'ADR-[0-9]{4}' \
                 --include='*.md' --include='*.dart' --include='*.py' \
                 --include='*.sh' --include='Makefile' . 2>/dev/null \
               | sort -u); do
    num=${ref#ADR-}
    ls docs/adr/"$num"-*.md >/dev/null 2>&1 || dangling="$dangling $ref"
  done
  if [ -n "$dangling" ]; then
    err "cited but never written — the citation claims a rationale that does not exist:$dangling"
  else
    ok "every ADR referenced anywhere in the repo exists"
  fi
fi

# --- 6. THE ONE THAT MATTERS -----------------------------------------------
# Did code change since the last journal entry? If so, something was built and
# nothing recorded why. This is the check the whole file exists for.
if [ -d .git ] && [ -f docs/JOURNAL.md ]; then
  last_journal=$(git log -1 --format=%ct -- docs/JOURNAL.md 2>/dev/null || echo 0)
  last_code=$(git log -1 --format=%ct -- lib app/lib 2>/dev/null || echo 0)
  if [ "$last_code" -gt "$last_journal" ] 2>/dev/null; then
    since=$(( (last_code - last_journal) / 86400 ))
    note "code has changed since the last journal entry (${since}d) — run 'make journal'"
  else
    ok "the journal is current with the code"
  fi
fi

printf '\n'
if [ "$fail" -gt 0 ]; then
  printf '%s%d problem(s), %d warning(s)%s\n' "$RED" "$fail" "$warn" "$OFF"
  exit 1
fi
printf '%sdocumentation gate passed%s' "$GRN" "$OFF"
[ "$warn" -gt 0 ] && printf ' %s(%d warning(s))%s' "$DIM" "$warn" "$OFF"
printf '\n'
